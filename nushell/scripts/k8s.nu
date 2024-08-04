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

# Like the linux `nsenter` command,
# it uses `circtl` enter the intput pod name.
# Note only the first container will entered.
export def nsenter [
    ...command: string # the command to use
]: string -> nothing {
    let podID = crictl pods --name $in --state=Ready | from ssv | get 0 | get 'POD ID'
    let containerID = crictl ps -a --pod $podID | from ssv | get 'CONTAINER' | get 0 # only the first one
    let pid = crictl inspect $containerID | from json | get info.pid
    ^nsenter -n -t $pid -- ...$command

    # TODO: why not work?
    # let pid = crictl pods --name $in --state=Ready | from ssv | get 0 | get 'POD ID'
    # | crictl ps -a --pod $in | from ssv | get 'CONTAINER' | get 0
    # | crictl inspect $in | from json | get info.pid
    # | ^nsenter -n -t $in -- ...$command
}