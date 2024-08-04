# Returns the number of non-leap timestamp since January 1, 1970 0:00:00 UTC (aka “UNIX timestamp”).
export def "to-timestamp" [
    --unit (-u): string = "sec" # Unit to convert number into, one of [ns us ms sec(default)]
]: datetime -> int {
    let nanos = $in | into int
    $nanos / (10 ** match $unit {
        "ns" => 0
        "us" => 3
        "ms" => 6
        _ => 9
    }) | into int
}

# reverse is `into datetime` whose input is a nanosecond