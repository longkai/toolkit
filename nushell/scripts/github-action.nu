# Fetch the latest version for a github repository.
# If the version tag starts with v, e.g. v1.2.3, it will return 1.2.3
#
# The input is The owner and repository name. For example, octocat/Hello-World.
export def latest-version []: string -> string {
    http get $"https://api.github.com/repos/($in)/releases/latest"
    | get tag_name
    | str trim --left --char 'v'
}

# Format the input into multi-line step output
#
# Ref https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/workflow-commands-for-github-actions#multiline-strings
export def multi-line [
    key: string # the output key
]: string -> string {
    $"($key)<<EOF\n($in)\nEOF\n"
}

