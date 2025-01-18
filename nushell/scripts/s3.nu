use helper *

def "from aws toml" []: string -> record {
    $in | path expand | open $in
        | each { |it| $it | str replace -r -a r#'(.+)([\s]?)=([\s])?(.+)'# '${1}${2}=${3}"${4}"' }
        | str join "\n"
        | from toml
}

export def get-config [
    --access-key: string
    --secret-key: string
    --region: string
    --endpoint-url: string
]: nothing -> record<aws_access_key_id: string, aws_secret_access_key: string, endpoint_url: string, region: string, bucket: string> {
    if ($access_key != null) {
        return {
            aws_access_key_id: $access_key
            aws_secret_access_key: $secret_key
        }
    }
    let config = try {
        '~/.aws/config' | from aws toml | get default
    } catch {
        {}
    }
    let region = $region | default $config.region? | default 'us-east-1'
    '~/.aws/credentials'
    | from aws toml
    | get default
    | upsert region $region
    | upsert endpoint_url { |it| $endpoint_url | default $it.endpoint_url? | default $'https://s3.($region).amazonaws.com' }
}

def parse-s3-uri []: string -> record<bucket: string, path: string> {
    $in | parse "s3://{bucket}/{path}" | into record
}

def curl-aws [
    --access-key: string
    --secret-key: string
    --path: string = "/"
    --method: string = "GET"
    --region: string = 'us-east-1'
    --service: string = 's3'
    --endpoint: string
] {
    curl -s -v -X $method $"($endpoint)($path)" --user $'($access_key):($secret_key)' --aws-sigv4 $"aws:amz:($region):($service)"
}

# use the bucket as virtual host with the input endpoint if any.
def virtual-host [
    bucket: string
]: string -> string {
    let u = $in | url parse
    let host = $'($bucket).($u.host)'
    if (dig $host +short | is-not-empty) { # valid domain name
        return $'($u.scheme)://($host)'
    }
    $in
}

# generate aws s3 presigned url with the s3uri, or with the input.
#
# reference doc: https://docs.aws.amazon.com/AmazonS3/latest/API/sigv4-query-string-auth.html
#
# Examples:
#
# - GET presigned url: s3 presign "s3://my-bucket/path/to/file.txt"
# - PUT presigned url with expiry: "s3 presign "s3://my-bucket/path/to/file.txt" --method PUT --expires-in 2hr
# - use input pipeline: "s3://my-bucket/path/to/file.txt" | s3 presign
# - use `bucket` in `~/.aws/credentials` [default] profile: "s3:///path/to/file.txt" | s3 presign
export def presign [
    s3uri?: string # aka. `s3://<bucket>/path/to/obj`, default use `$in`
    --access-key: string # aws access key, default to `~/.aws/credentials` [default] profile
    --secret-key: string # aws secret key, default to `~/.aws/credentials` [default] profile
    --now: datetime # default use current time
    --expires-in: duration = 1hr # presigned url expiry
    --method: string = 'GET' # presigned url method, `GET` or `PUT`
    --query: record = {} # customized query parameters
    --headers: record = {} # customized headers
    --endpoint-url: string # base endpoint url if not use aws, e.g., `https://cos.ap-guangzhou.myqcloud.com`, default to `~/.aws/credentials` [default] profile
    --service: string = 's3' # signed service, should be `s3`
    --region: string # service region, doesn't matter if not use aws, default to `~/.aws/config` [default] profile
    --algorithm: string = 'AWS4-HMAC-SHA256' # don't change it
]: [
    string -> string
    nothing -> string
] {
    let config = get-config --access-key $access_key --secret-key $secret_key --region $region --endpoint-url $endpoint_url
    let s3_proto = $in | default $s3uri | parse-s3-uri
    let bucket = if ($s3_proto.bucket | is-not-empty) { $s3_proto.bucket } else { $config.bucket }
    let path = $s3_proto.path
    let region = $config.region
    let now = $now | default (date now | date to-timezone utc)
    let endpoint_url = $config.endpoint_url
    let virtual_host = $endpoint_url | virtual-host $bucket
    let path = if $virtual_host == $endpoint_url { ['/' $bucket $path]  | path join } else { ['/' $path] | path join }
    let endpoint_url = $virtual_host

    let url_parts = $endpoint_url | url parse
    let hdr = $headers | transpose k v
        | reduce -f {} { |it, acc| $acc | upsert ($it.k | str downcase) $it.v }
        | upsert 'host' $url_parts.host
    let query = $query
        | upsert 'X-Amz-Algorithm' $algorithm
        | upsert 'X-Amz-Credential' $'($config.aws_access_key_id)/($now | format date '%Y%m%d')/($region)/s3/aws4_request'
        | upsert 'X-Amz-Date' ($now | format date '%Y%m%dT%H%M%SZ')
        | upsert 'X-Amz-Expires' ($expires_in / 1sec)
        | upsert 'X-Amz-SignedHeaders' 'host'
    let canonicalRequest = [
        ($method | str upcase)
        ([$endpoint_url $path] | path join)
        ($query | url build-query | split row '&' | sort | str join '&')
        (
            $hdr | transpose k v
                | reduce -f [] { |it, acc| $acc | append $"($it.k):($it.v)" }
                | sort
                | reduce -f "" { |it, acc| $acc + $it + "\n" }
        )
        ($hdr | sort | columns | str join ';')
        "UNSIGNED-PAYLOAD"
    ] | str join "\n"

    log debug $'canonicalRequest => ($canonicalRequest)'

    let stringToSign = [
        $algorithm
        ($now | format date '%Y%m%dT%H%M%SZ')
        ([($now | format date '%Y%m%d') $region $service "aws4_request"] | str join "/")
        ($canonicalRequest | hash sha256)
    ] | str join "\n"

    log debug $"str to sign => ($stringToSign)"

    let kDate = ($now | format date '%Y%m%d') | hmac256-digest ($"AWS4($config.aws_secret_access_key)" | encode utf-8)
    let kRegion = $region | hmac256-digest $kDate
    let kService = $service | hmac256-digest $kRegion
    let kSigning = "aws4_request" | hmac256-digest $kService

    log debug $"singing key => ($kSigning | encode hex --lower)"

    let signature = $stringToSign | hmac256-digest $kSigning | encode hex --lower

    log debug $"signature => ($signature)"

    $'($endpoint_url)($path)?($query | insert X-Amz-Signature $signature | url build-query)'
}
