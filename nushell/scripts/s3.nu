use helper *
use std log

def get-credential [
    --access-key: string
    --secret-key: string
]: nothing -> record<aws_access_key_id: string, aws_secret_access_key: string> {
    if ($access_key != null) {
        return {
            aws_access_key_id: $access_key
            aws_secret_access_key: $secret_key
        }
    }
    open ~/.aws/credentials
    | lines
    | each { |it| $it | str replace -r -a "(.+) = (.+)" '${1} = "${2}"' }
    | str join "\n"
    | from toml
    | get default
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

export def presign [
    s3uri?: string
    --access-key: string
    --secret-key: string
    --now: datetime
    --expires-in: duration = 1hr
    --method: string = 'GET'
    --query: record = {}
    --headers: record = {}
    --endpoint-url: string
    --service: string = 's3'
    --region: string = 'us-east-1'
    --algorithm: string = 'AWS4-HMAC-SHA256'
]: [
    string -> string
    nothing -> string
] {
    let s3_proto = $in | default $s3uri | parse-s3-uri
    let bucket = $s3_proto.bucket
    let path = $s3_proto.path
    let cred = get-credential --access-key $access_key --secret-key $secret_key
    let now = if $now == null { date now | date to-timezone utc } else { $now }
    let endpoint_url = $endpoint_url | option-or-env S3_ENDPOINT_URL | default $'https://s3.($region).amazonaws.com'
    let virtual_host = $endpoint_url | virtual-host $bucket
    let path = if $virtual_host == $endpoint_url { ['/' $bucket $path]  | path join } else { ['/' $path] | path join }
    let endpoint_url = $virtual_host

    let url_parts = $endpoint_url | url parse
    let hdr = $headers | transpose k v
        | reduce -f {} { |it, acc| $acc | upsert ($it.k | str downcase) $it.v }
        | upsert 'host' $url_parts.host
    let query = $query
        | upsert 'X-Amz-Algorithm' $algorithm
        | upsert 'X-Amz-Credential' $'($cred.aws_access_key_id)/($now | format date '%Y%m%d')/us-east-1/s3/aws4_request'
        | upsert 'X-Amz-Date' ($now | format date '%Y%m%dT%H%M%SZ')
        | upsert 'X-Amz-Expires' ($expires_in / 1sec)
        | upsert 'X-Amz-SignedHeaders' 'host'
    let canonicalRequest = [
        $method
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

    log debug $'canonicalRequest: ($canonicalRequest)'

    let stringToSign = [
        $algorithm
        ($now | format date '%Y%m%dT%H%M%SZ')
        ([($now | format date '%Y%m%d') $region $service "aws4_request"] | str join "/")
        ($canonicalRequest | hash sha256)
    ] | str join "\n"

    log debug $"str to sing => ($stringToSign)"

    let kDate = ($now | format date '%Y%m%d') | hmac256-digest ($"AWS4($cred.aws_secret_access_key)" | encode utf-8)
    let kRegion = $region | hmac256-digest $kDate
    let kService = $service | hmac256-digest $kRegion
    let kSigning = "aws4_request" | hmac256-digest $kService

    log debug $"singing key: ($kSigning | encode hex --lower)"

    let signature = $stringToSign | hmac256-digest $kSigning | encode hex --lower

    log debug $"signature: ($signature)"

    $'($endpoint_url)($path)?($query | insert X-Amz-Signature $signature | url build-query)'
}
