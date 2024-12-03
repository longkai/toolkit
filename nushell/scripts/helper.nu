# check input option value is present, if not fallback to the given env key.
# if nothing found, return null.
export def option-or-env [
    key: string
]: any -> any {
    if $in == null {
        if $key in $env {
            $env | get $key
        } else {
            null
        }
    } else {
        $in
    }
}

# if input is empty then use default.
export def or-default [default: any]: any -> any {
    if ($in | is-empty) { $default } else { $in }
}