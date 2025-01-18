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

# Creates a datetime from the number of non-leap timestamp since January 1, 1970 0:00:00.000 UTC (aka “UNIX timestamp”).
# The default unit is seconds, change it with `unit` flag.
export def "from-timestamp" [
    --unit (-u): string = "sec" # Unit to parse number from, one of [ns us ms sec(default)]
    --timezone: string = "local"
    --offset: int
]: int -> datetime {
    $in * (10 ** match $unit {
        "ns" => 0
        "us" => 3
        "ms" => 6
        _ => 9
    }) | if $offset == null {
        $in | into datetime --timezone $timezone
    } else {
        $in | into datetime --offset $offset
    }
    # unix timestamp could specify timezone, offset has high priority and timezone must be one of [utc, local]
}
