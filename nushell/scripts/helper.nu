# hmac the input string with the key to the binary digest
export def hmac256-digest [
    hex_key: binary
]: string -> binary {
    $in | openssl dgst -sha256 -mac hmac -macopt $"hexkey:($hex_key | encode hex)" -binary
}
