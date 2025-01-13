#!/usr/bin/env -S nu --stdin
use helper *
use s3 *

# turn '<registry>/<namespace>/<repo>:<tag>' to '<repo>/<tag>.tar'
def "into local-file-name" []: string -> string {
    $in | path split | last | split row ':' | path join | $in + '.tar'
}

# download the input oci image url as a local tarball in the current dir.
# return the filename, path format is `<svc>/<tag>.tar`
def pull [
    --force (-f) # wether to force download if file already exists, note `latest` tag is always downloaded.
    --platform: string
]: string -> string {
    let url = $in
    let dst = $url | into local-file-name
    $dst | path dirname | mkdir $in # TODO(kennylong): how to do it in a chain without break?
    $dst
    | if $force or not ($in | path exists) or ($in | path parse | $in.stem == 'latest') {
        log info $'downloading ($url) to ($in)'
        crane pull --platform $platform $url $in
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

def parse-oci-image-ref []: string -> record<registry: string, namespace: string, name: string, tag: string, digest: string> {
    mut input = $in
    if $input starts-with 'docker.io/' {
        $input = ($input | str substring ('docker.io/' | str length)..)
    }
    if $input starts-with 'library/' {
        $input = ($input | str substring ('library/' | str length)..)
    }
    $input
    | parse --regex r#'^(?:(?P<registry>[a-zA-Z0-9._-]+(?:\:[0-9]+)?)\/)?(?:(?P<namespace>[a-z0-9]+(?:[._-][a-z0-9]+)*)\/)?(?P<name>[a-z0-9]+(?:[._-][a-z0-9]+)*)(?::(?P<tag>[a-zA-Z0-9._-]+))?(?:@(?P<digest>sha256:[a-f0-9]{64}))?$'#
    | into record
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
        tar tf $input | grep $'^($manifest)$'
        tar xf $input $manifest
        let out = open manifest.json | get 0.RepoTags.0 | parse-oci-image-ref
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
    let out = open ([$dir $conf] | path join) | from json | get type? | $in in [application library]
    | if $in {
        let dst = mktemp -t oci-chart.XXXX
        log debug $'($input) is a helm chart and transform it to ($dst)'
        open ([$dir manifest.json] | path join) | get 0.Layers.0 | cp $in $dst
        $dst
    } else {
        $input
    }
    rm -rf $dir
    $out
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
        # remote registry or local registry?
        # local has a high priority since the remote it's also pushed from locally.
        # try `docker` instead `ctr` cannot build image itself.

        let ref = $input | parse-oci-image-ref
        log debug $'ref parse: ($ref)'
        if ($ref | is-empty) {
            log debug $'cannot parse as a oci image ref ($input)'
            return $input
        }
        let repo = $ref | [$in.registry $in.namespace $in.name] | path join
        # digest has the highest priority and ignore tag if tag is present
        # if no digest, use tag, if no tag, tag is latest
        # if no tag, but digest, use digest
        let digest = if ($ref.digest | is-empty) { '' } else { $ref.digest | str substring ('sha256:' | str length).. }
        let tag = if ($ref.tag | is-empty) { 'latest' } else { $ref.tag }

        let cmd = if (which docker | is-not-empty) {
            docker images
        } else if (which nerdctl | is-not-empty) {
            docker images
        } else { # TODO(kennylong): use ctr export?
            log debug $'no docker or nerdctl found, use remote: ($input)'
            return $input
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
    let url = try {
        $url | url parse
    } catch { |err|
        log debug $'parse url ($url) fail: ($err)'
        {scheme: ''}
    }
    match $url.scheme {
        'http' | 'https' => {
            let out = mktemp -t oci-image.XXXX
            $url | url join | curl -L -o $out $in
            $out
        }
        'file' => {
            [$url.host $url.path] | filter { |it| $it != '/' } | path join
        }
        _ => {
            $input | pull --platform $platform
        }
    }
}

# push oci images to the remote registry.
#
# input may be one of: [another registry, a downloadable tar like s3, a local image or a local tarball]
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

# import images from urls or local tarballs, concurrently.
#
# it will auto-detect use `docker` or `ctr`.
export def import []: [
    string -> nothing
    list<string> -> nothing
] {
    let input = $in
    $in | par-each {|it|
        try {
            # try download then fallback to a local file
            let dst = mktemp -t oci-image.XXXX
            curl -L -o $dst $it
            $dst
        } catch { $input }
        | if (which docker | is-empty) {
            log debug $'using ctr to load image ($in)'
            ctr -n k8s.io i import $in
            $in
        } else {
            log debug $'using docker to load image ($in)'
            docker load -i $in
            $in
        } | if $input != $in { rm -rf $in }
    }
}

# upload(sync) oci images into s3 and given back the pre-signed download urls.
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
    let bucket = $bucket | default $config.bucket
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
