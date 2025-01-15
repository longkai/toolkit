# Parse the envoy text based access log and return the table with the pattern records.
export def parse-access-log [
    pattern?: string # if not set, use the default standard format pattern
    --regex (-r) # use full regex syntax for patterns
    --tencent-cloud-action # append a tencent cloud api action at the end of the default standard format
    --strip-missing-value # whether to strip missing(null) value from records
    --into-datetime # whether to convert start-time to datetime type instead of string
]: any -> table {
    let default_pattern = $pattern == null
    let pattern = if $default_pattern { '[{START_TIME}] "{METHOD} {PATH} {PROTOCOL}" {RESPONSE_CODE} {RESPONSE_FLAGS} {BYTES_RECEIVED} {BYTES_SENT} {DURATION} {X_ENVOY_UPSTREAM_SERVICE_TIME} "{X_FORWARDED_FOR}" "{USER_AGENT}" "{X_REQUEST_ID}" "{AUTHORITY}" "{UPSTREAM_HOST}"' } else { $pattern }
    let pattern = if $tencent_cloud_action and $default_pattern { $pattern + ' "{X_TC_ACTION}"'} else { $pattern }
    $in
    | lines --skip-empty
    | par-each --keep-order { |line|
        $line | parse $pattern --regex=$regex
    }
    | par-each --keep-order { |it|
        if not $default_pattern {
            return $it | into record
        }
        let entry = $it | transpose k v | reduce -f {} { |it, acc|
            $acc | upsert ($it.k | str downcase | str kebab-case) (
                # unset values are represented as null values and empty strings are rendered as ""
                match $it.k {
                    START_TIME => {
                        $it.v | into datetime | into int | into datetime --timezone l
                        | if $into_datetime { $in } else {
                            $in | format date '%Y-%m-%dT%H:%M:%S%.3f%:z'
                        }
                    }
                    RESPONSE_CODE => { $it.v | into int }
                    BYTES_RECEIVED | BYTES_SENT => { $it.v | into filesize }
                    DURATION | X_ENVOY_UPSTREAM_SERVICE_TIME => {
                        if $it.v == "-" { null } else { $it.v | into int | into duration --unit ms}
                    }
                    _ => { if $it.v == "-" { null } else { $it.v } }
                }
            )
        }
        if not $strip_missing_value {
            return $entry
        }
        let rejects = $entry | items { |k,v| if ($v | is-empty) { $k } else { '' } } | filter {|it| $it != '' }
        $entry | reject ...$rejects
    }
}
