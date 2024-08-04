# Parse the [semantic versioning(https://semver.org/).
# the return value will be a record with major, minor and patch keys.
#
# the input must be the version name, note it should not starts with v, e.g., v1.2.3
export def semver []: string -> record {
    $in | parse "{major}.{minor}.{patch}" | get 0
}