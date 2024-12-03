# Parse the envoy standard text based access logging format.
export def parse-access-log [
    --format: string = '[{START_TIME}] "{METHOD} {PATH} {PROTOCOL}" {RESPONSE_CODE} {RESPONSE_FLAGS} {BYTES_RECEIVED} {BYTES_SENT} {DURATION} {X_ENVOY_UPSTREAM_SERVICE_TIME} "{X_FORWARDED_FOR}" "{USER_AGENT}" "{X_REQUEST_ID}" "{AUTHORITY}" "{UPSTREAM_HOST}"'
]: any -> table {
    $in
    | lines
    | each { |row|
        $row | parse $format
    } | flatten
}