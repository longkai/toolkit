# Create and run a particular image in a pod.
export def run [
    --name: string
    --namespace (-n): string = "" # if not specify, is `nothing`
    --image-pull-policy: string = "Always"
    ...command: string # if not set, use default command and arguments
]: string -> nothing {
    let image = $in
    if $name == null {
        $image | split row / | last | split row : | get 0
        # $name = date now | format date "%-m-%-d-%H-%M"
    } else {
        $name
    } | kubectl run $in -n $namespace --restart 'Never' --image $image --image-pull-policy $image_pull_policy --command -- ...$command
}
