#!/usr/bin/env -S nu --stdin
use s3 *

# turn '<registry>/<namespace>/<repo>:<tag>' to '<repo>/<tag>.tar'
def "into local-file-name" []: string -> string {
    let dict = $in | parse-oci-image-url
    [$dict.name ($dict.digest | default $dict.tag)] | path join | $in + ".tar"
}

# download the input oci image url as a local tarball in the current dir.
# return the filename, path format is `<svc>/<tag>.tar`
def pull [
    --force (-f) # wether to force download if file already exists, note `latest` tag is always downloaded.
    --platform: string
]: string -> string {
    let url = $in
    let dst = $url | into local-file-name
    let ref = $url | parse-oci-image-url
    $dst | path dirname | mkdir $in # TODO(kennylong): how to do it in a chain without break?
    $dst
    | if $force or not ($in | path exists) or ($ref.tag == 'latest') {
        log info $'downloading ($url) to ($in)'
        crane pull --platform $platform $ref.full_url $in
        $in
    } else {
        log info $'($in) already exists'
        $in
    }
}

# input is a local file named `<svc>/<tag>.tar`
def s3-sync [
    --prefix: string = 'oci-images'
    --bucket: string
    --endpoint-url: string
]: string -> string {
    let src = $in
    $in
    | path parse
    | do {
        log info $'sync local dir ($in.parent) including ($in.stem).($in.extension) to s3://([$bucket $prefix $in.parent] | path join)'
        aws s3 sync $in.parent $'s3://([$bucket $prefix $in.parent] | path join)' --exclude '*' --include $'($in.stem).($in.extension)' --endpoint-url $endpoint_url
        log info 'sync success'
        [$prefix $src] | path join
    }
}

def is-tencent-cloud []: nothing -> bool {
    try {
        cat /sys/devices/virtual/dmi/id/sys_vendor | $in == "Tencent Cloud"
    } catch { false }
}

def is-domain []: string -> bool {
    host $in | complete | $in.exit_code == 0
}

def parse-oci-image-url []: string -> record<registry: string, namespace: string, name: string, tag: string, digest: string, full_url: string> {
    # 1 => nginx
    # 2 => library/nginx, kennylongio/toolkit, registry.k8s.io/kube-apiserver:v1.34.1 # authority like docker library without `library`
    # 3 => registry/library/nginx
    # 4 => registry/main/sub/nginx

    let segs = $in | split row '/'
    let ref = $segs | last
    match ($segs | length) {
        1 => {
            registry: 'docker.io'
            namespace: 'library'
        }
        2 => {
            mut registry = 'docker.io'
            mut ns = ($segs | first)
            if ($segs | first | is-domain) {
                $registry = $segs | first
                $ns = ''
            }
            {
                registry: $registry
                namespace: $ns
            }
        }
        _ => {
            registry: ($segs | first)
            namespace: ($segs | slice 1..-2 | str join '/')
        }
    } | merge ($segs | last | parse-oci-image-ref) | upsert registry { |dict|
        # TODO: change to mirror in different vendor?
        if (is-tencent-cloud) and ($dict.registry == 'docker.io') {
            'mirror.ccs.tencentyun.com'
        } else { $dict.registry }
    } | upsert full_url {|dict|
        let url = [$dict.registry $dict.namespace $dict.name] | where ($it | is-not-empty) | str join '/'
        if ($dict.digest | is-not-empty) {
            $url + '@' + $dict.digest
        } else {
            $url + ":" + $dict.tag
        }
    }
}

def parse-oci-image-ref []: string -> record<name: string, tag: string, digest: string> {
    let segs = $in | split row '@'
    let digest =  $segs | get 1?
    let segs = $segs | first | split row ':'
    # digest has the highest priority
    let tag = if ($digest | is-not-empty) { null } else { $segs | get 1? | default 'latest' }
    {
        name: ($segs | first)
        tag: $tag
        digest: $digest
    }
}

def default-platform []: nothing -> string {
    let info = $nu.os-info
    let arch = match $info.arch {
        'x86_64' => 'amd64'
        'aarch64' => 'arm64'
        _ => $info.arch # may not work...
    }
    [$info.name $arch] | path join
}

def parse-oci-manifest []: string -> record<registry: string, namespace: string, name: string, tag: string, digest: string> {
    const manifest = 'manifest.json'
    let input = $in
    try {
        tar tf $input | grep -q $'^($manifest)$'
        tar xf $input $manifest
        let out = open manifest.json | get 0.RepoTags.0 | parse-oci-image-url
        rm $manifest
        $out
    } catch { |err|
        # not found
        log debug $'($manifest) not found in tarball ($input), treat it as a helm chart tgz'
        let file = tar tf $input | grep -E '^([^/]+)/Chart.yaml$'
        tar xf $input $file
        let chart = open $file
        if $chart.type? not-in [application library] {
            error make {msg: $'not a helm chart tgz'}
        }
        rm -rf $file
        {registry: '' namespace: '' name: $chart.name tag: $chart.version digest: ''}
    }
}

# if the input tarball path is a helm chart, the return value will not equal to the input.
def helm-chart-oci []: string -> string {
    let input = $in
    try {
        let file = tar tf $input | grep -E '^([^/]+)/Chart.yaml$'
        tar xf $input $file
        if (open $file | $in.type? in [application library]) {
            log debug $'($input) is an helm chart tgz'
            rm $file
            let out = mktemp -t oci-chart.XXXX
            cp $input $out # just copy as another tgz
            return $out
        }
        rm $file
    } catch { |err|
        log debug $'($input) is not a helm chart tgz, try as oci tarball'
    }

    let dir = mktemp --directory
    tar xf $in -C $dir
    let conf = open ([$dir manifest.json] | path join) | get 0.Config
    let out = open -r ([$dir $conf] | path join) | from json | get type? | $in in [application library]
    | if $in {
        let dst = mktemp -t oci-chart.XXXX
        log debug $'($input) is a helm chart and transform it to ($dst)'
        open ([$dir manifest.json] | path join) | get 0.Layers.0 | cp ([$dir $in] | path join) $dst
        $dst
    } else {
        $input
    }
    rm -rf $dir
    $out
}

def tarball-image-tag []: string -> string {
    tar -xOf $in manifest.json | from json | get 0.RepoTags.0
}

def dl [
    --platform: string
]: string -> string {
    let input = $in
    let platform = if ($platform | is-empty) { default-platform } else { $platform }
    let url = do {
        if ($input | path exists) {
            log debug $'a local file already exists: ($input)'
            return $'file://($input)'
        }

        try {
            # a downloadable tarball url
            $input | url parse
            return $input
        } catch { }

        # remote registry or local registry?
        # local has a high priority since the remote it's also pushed from locally.
        # try `docker` instead `ctr` cannot build image itself.

        let ref = $input | parse-oci-image-url
        log debug $'ref parse: ($ref)'
        if ($ref | is-empty) {
            log debug $'cannot parse as a oci image ref ($input)'
            return $input
        }
        let repo = $ref | [$in.registry $in.namespace $in.name] | path join
        # digest has the highest priority and ignore tag if digest is present
        # if no digest, use tag, if no tag, tag is latest
        # if no tag, but digest, use digest
        let digest = if ($ref.digest | is-empty) { '' } else { $ref.digest | str substring ('sha256:' | str length).. }
        let tag = if ($ref.tag | is-empty) { 'latest' } else { $ref.tag }

        let cmd = if (which docker | is-not-empty) {
            docker images
        } else if (which nerdctl | is-not-empty) {
            nerdctl images
        } else { # TODO(kennylong): use ctr export?
            log debug $'no docker or nerdctl found, use remote: ($input)'
            return $ref.full_url
        }
        let images = $cmd | from ssv
        | where REPOSITORY == $repo and PLATFORM == $platform # TODO(kennylong): what if platform for all?
        | where if ($digest | is-empty) { $it.TAG == $tag } else { $it."IMAGE ID" == $digest }
        if ($images | length) == 1 {
            let out = mktemp -t oci-image.XXXX
            log debug $'found one exact local image ($input) and save it as ($out)'
            if (which docker | is-empty) { nerdctl save $images.0."IMAGE ID" -o $out } else { docker save $images.0."IMAGE ID" -o $out }
            return $'file:///($out)'
        }
        if ($images | length) > 0 {
            error make {msg: $'multiple images found: ($images)' }
        }
        # TODO: can we push a image only with sha256? most likely no
        log debug $'use remote image: ($input)'
        $input
    }
    log debug $'full url: ($url)'
    let url = try {
        $url | url parse
    } catch { |err|
        log debug $'parse url ($url) fail: ($err)'
        {scheme: ''}
    }
    match $url.scheme {
        'http' | 'https' => {
            let out = mktemp -t oci-image.XXXX
            $url | url join | curl -L --fail-with-body -o $out $in
            $out
        }
        'file' => {
            [$url.host $url.path] | where $it != '/' | path join
        }
        _ => {
            $input | pull --platform $platform
        }
    }
}

# Push oci images to the remote registry.
#
# Input may be one of: [another registry, a downloadable tar like s3, a local image or a local tarball]
# helm chart is also support
export def "push registry" [
    registry?: string # the remote registry host, if null pushing to the image tag itself.
    --namespace(-n): string # the pushed registry namespace if any
    --name: string
    --tag(-t): string # the pushed image tag if nay
    --insecure # whether the registry is insecure
    --platform: string
]: [
    string -> string
    list<string> -> list<string>
] {
    $in | par-each {|it|
        let tarball = $it | dl --platform $platform
        let ref = $tarball | parse-oci-manifest
        let registry = $registry | default $ref.registry
        let ns = $namespace | default $ref.namespace | default 'library'
        let name = $name | default $ref.name
        let tag = $tag | default $ref.tag | default 'latest'

        let dst = [$registry $ns $name] | path join | $in + ':' + $tag
        $tarball | helm-chart-oci | if $in != $tarball {
            let oci = $'oci://($registry)/($ns)'
            log info $'push a helm chart ($in) to ($oci)'
            helm push $in $oci
        } else {
            log info $'pushing ($it) as ($tarball) to ($dst)'
            crane push $tarball $dst --insecure=($insecure)
        }

        # clean tmp file
        if $it != $tarball {
            log debug $'delete tmp file ($tarball)'
            rm -rf $tarball
        }
        $dst
    }
}

# Import images from urls or local tarballs, concurrently.
#
# It will auto-detect use `docker` or `ctr`.
@example "download a image tarball from the url then import into local node" { "https://..." | oci import } --result docker.io/library/nginx:latest
export def import []: [
    string -> string
    list<string> -> list<string>
] {
    let input = $in
    $in | par-each {|it|
        let tarball = try {
            # try download then fallback to a local file
            let dst = mktemp -t oci-image.XXXX
            curl --fail-with-body -L -o $dst $it
            $dst
        } catch { $it }
        if (which docker | is-empty) {
            log debug $'using ctr to load image ($tarball)'
            ctr -n k8s.io i import $tarball
        } else {
            log debug $'using docker to load image ($tarball)'
            docker load -i $tarball
        }
        let tag = $tarball | tarball-image-tag
        if $it != $tarball { rm -rf $tarball }
        $tag
    }
}

def resolve-hosts []: any -> any {
    let input = $in
    let type = $input | describe
    match $type {
        string => { host: $input }
        list<string> => ( $input | each {|| { host: $in } } )
        $x if $x starts-with record => (match $input {
            {host: _} => $input
            _ => { error make { msg: $"invalid record type ($x), no `host` field found" } }
        })
        nothing => {
            log debug $'nothing input, try list k8s nodes'
            kubectl get nodes -o wide | from ssv | get INTERNAL-IP | each {|host|
                { host: $host }
            }
        }
        _ => $input # anyway, just try to get `host` from input
    }
}

# Import images to all the k8s daemonset nodes. Note the daemonset must mount containerd socket and `ctr` binary.
#
@example "download an image tarball url then import into all k8s daemonset nodes" { "https://..." | oci import daemonset -n default -l name=toolkit } --result [docker.io/library/app:latest]
@example "like above, but with a list of url" { "[https://...]" | oci import daemonset -n default -l name=toolkit } --result [[docker.io/library/app:latest]]
export def "import daemonset" [
    --selector (-l): string = 'name=toolkit' # the pod labels of the toolkit daemonset
    --namespace (-n): string = '' # the namespace of the toolkit pod
]: [
    string -> string
    list<string> -> list<string>
 ] {
    let input = $in | to json --raw
    kubectl get po -n $namespace -l $selector -owide | from ssv | par-each --keep-order { |it|
        log info $'executing pod ($it.NAME) on ($it.NODE)'
        kubectl exec -n $namespace $it.NAME -- nu --login -c $"($input) | oci import | to json --raw"
            | lines --skip-empty | last | from json
    }
}

# Import images to the remote hosts using scp/ssh.
#
# The input is the output from `push s3` command.
export def "import ssh" [
    # hosts: list<record<host: string, user?: string, port?: int>> # the ssh/scp remote targets, default to all k8s nodes
    hosts?: any # the ssh/scp remote targets one of [string(host), list<string(host)>, record<host: string, user?: string, port?: int>, or a list of the that record], default to all k8s nodes
    --ctr-or-docker: string # the remote host use `docker` or `ctr` or other command you can specify to import oci images to local
    --user: string = 'root' # the default ssh remote user, if not specify with `hosts` positional arg
    --port: int = 22 # the default ssh remote port, if not specify with `hosts` positional arg
]: [
    record<url: string, image: string> -> nothing
    list<record<url: string, image: string>> -> nothing
] {
    let tarballs = $in | par-each {|it|
        let dst = mktemp -t oci-image.XXXX
        curl --fail-with-body -o $dst -L $it.url
        [ $dst ]
    } | flatten # always be an array since var args below

    let hosts = $hosts | resolve-hosts
    let cmd = if $ctr_or_docker == null {
        kubectl get node -o wide | from ssv | get CONTAINER-RUNTIME | first | str starts-with 'containerd://' | if $in { 'ctr' } else { 'docker' }
    } else { $ctr_or_docker }

    let shell = $tarballs | each {|file|
        if $cmd == 'ctr' {
            $'ctr -n k8s.io i import ($file)' # Note: --base-name foo/bar
        } else {
            $'($cmd) load -i ($file)'
        } | $'($in); rm -rf ($file);'
    } | prepend 'PATH=/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin ' | str join ''

    $hosts | each {|it|
        let port = $it.port? | default $port
        let user = $it.user? | default $user
        let remote = [$user $it.host] | str join '@'

        log debug $'scp oci tarballs to ($remote)...'
        scp -P $port ...$tarballs $'($remote):/tmp'

        log debug $'ssh to load oci tarballs to ($remote) with: ($shell)'
        ssh $remote -p $port $'sh -c "($shell)"'
    }
}

# Upload(sync) oci images into s3 then given back the pre-signed download urls.
@example "push a remote image to s3 as a tarball downloadable url" { "nginx" | oci push s3 } --result {"url": "https://cos.ap-guangzhou.myqcloud.com/...", "name": "nginx"}
export def "push s3" [
    --bucket: string # the s3 bucket to put, default to `~/.aws/credentials` [default] profile
    --endpoint-url: string # the s3 endpoint-url to put, default to `~/.aws/credentials` [default] profile
    --platform: string
    --expires-in: duration = 6hr
]: [
    string -> record<url: string, image: string>
    list<string> -> list<record<url: string, image: string>>
] {
    let config = get-config --endpoint-url $endpoint_url
    let bucket = $bucket | default $config.bucket?
    let platform = $platform | default (default-platform)
    $in | par-each {|it|
        $it | pull --platform $platform
        | s3-sync --bucket $bucket --endpoint-url $config.endpoint_url
        | aws s3 presign --expires-in ($expires_in / 1sec) $'s3://([$bucket $in] | path join)' --endpoint-url $config.endpoint_url
        | {
            url: $in
            image: $it
        }
    }
}
