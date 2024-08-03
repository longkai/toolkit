# Fetch the latest version for a github repository.
# If the version tag starts with v, e.g. v1.2.3, it will return 1.2.3
export def latest-version [
    repository: string # The owner and repository name. For example, octocat/Hello-World.
] {
    http get $"https://api.github.com/repos/($repository)/releases/latest" |
    get tag_name | 
    str trim --left --char 'v'
}

# Parse the [semantic versioning(https://semver.org/).
# the return value will be a record with major, minor and patch keys.
export def semver [
    ver: string # the version name, note it should not starts with v, e.g., v1.2.3
] {
    $ver | parse "{major}.{minor}.{patch}" | get 0
}

# Write multi-line step output
#
# Ref https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/workflow-commands-for-github-actions#multiline-strings
export def multi-line-output [
    key: string # the output key
    content: string # the output content
] {
    $"($key)<<EOF\n($content)\nEOF\n" | save -a $env.GITHUB_OUTPUT
}

