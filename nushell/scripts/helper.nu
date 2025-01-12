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

# hmac the input string with the key to the binary digest
export def hmac256-digest [
    hex_key: binary
]: string -> binary {
    $in | openssl dgst -sha256 -mac hmac -macopt $"hexkey:($hex_key | encode hex)" -binary
}