#!/usr/bin/env nu
#
# kb-switch.nu - switch the Dell KB216 right Ctrl key between Left Option,
# Right Control, and Caps Lock, while preserving the macOS Modifier Keys
# mappings.
#
# Usage:
#   nu kb-switch.nu option     # Right Ctrl -> Left Option
#   nu kb-switch.nu control    # Right Ctrl -> Right Control (hardware identity)
#   nu kb-switch.nu capslock   # Right Ctrl -> Caps Lock (System Modifier Keys)
#   nu kb-switch.nu show       # Show the current mapping
#
# Import it to get structured data instead of rendered text:
#   use kb-switch.nu
#   kb-switch show | get from
#
# Or import the commands directly:
#   use kb-switch.nu *
#   show | where page == "keyboard"
#
# The plist is read and written through plutil's XML conversion and Nushell's
# from xml/to xml. PlistBuddy is not used at all.
#
# Apply the change by unplugging and replugging the keyboard. No logout or
# reboot is required.

const USAGE = "Usage: nu kb-switch.nu option|control|capslock|show"

const VID = 16700 # 0x413c Dell
const PID = 8467  # 0x2113 KB216
const KEY = $"com.apple.keyboard.modifiermapping.($VID)-($PID)-0"

const CAPSLOCK = 0x700000039
const LEFT_CTRL = 0x7000000E0
const LEFT_SHIFT = 0x7000000E1
const LEFT_ALT = 0x7000000E2
const LEFT_CMD = 0x7000000E3
const RIGHT_CTRL = 0x7000000E4
const RIGHT_SHIFT = 0x7000000E5
const RIGHT_ALT = 0x7000000E6
const RIGHT_CMD = 0x7000000E7
const FN_VENDOR_0 = 1095216660483
const FN_VENDOR_1 = 280379760050179

const USAGE_NAMES = [
    {value: $CAPSLOCK, name: "CapsLock"}
    {value: $LEFT_CTRL, name: "LeftCtrl"}
    {value: $LEFT_SHIFT, name: "LeftShift"}
    {value: $LEFT_ALT, name: "LeftAlt (Option)"}
    {value: $LEFT_CMD, name: "LeftCmd (GUI)"}
    {value: $RIGHT_CTRL, name: "RightCtrl"}
    {value: $RIGHT_SHIFT, name: "RightShift"}
    {value: $RIGHT_ALT, name: "RightAlt (Option)"}
    {value: $RIGHT_CMD, name: "RightCmd (GUI)"}
    {value: $FN_VENDOR_0, name: "Fn vendor (0xFF:3)"}
    {value: $FN_VENDOR_1, name: "Fn vendor (0xFF01:3)"}
]

const XML_HEADER = '<?xml version="1.0" encoding="UTF-8"?>' + "\n" + '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' + "\n"

def on-kbd-page [value: int] {
    ($value | bits shr 32) == 7
}

def usage-name [value: int] {
    $USAGE_NAMES | where value == $value | get name? | first | default $"Unknown ($value)"
}

def el [tag, content: list] {
    {tag: $tag, attributes: {}, content: $content}
}

def leaf [text: string] {
    [{tag: null, content: $text}]
}

def key-index [dict: record, key: string] {
    let matches = ($dict.content | enumerate | where {|it|
        $it.item.tag == "key" and ($it.item.content.0.content == $key)
    })
    if ($matches | is-empty) { null } else { $matches.0.index }
}

def dict-int [node: record, key: string] {
    let idx = (key-index $node $key)
    if ($idx | is-empty) {
        error make {msg: $"missing ($key) in mapping entry"}
    }
    let value = ($node.content | get ($idx + 1))
    $value.content.0.content | into int
}

def mapping-array [doc: record] {
    let dict = ($doc.content | where {|n| $n.tag == "dict"} | first)
    let idx = (key-index $dict $KEY)
    if ($idx | is-empty) {
        null
    } else {
        let node = ($dict.content | get ($idx + 1))
        if $node.tag != "array" {
            error make {msg: $"($KEY) is not an array"}
        }
        $node
    }
}

def entries-from-array [node: record] {
    $node.content
    | where {|n| $n.tag == "dict"}
    | each {|d|
        {
            src: (dict-int $d "HIDKeyboardModifierMappingSrc")
            dst: (dict-int $d "HIDKeyboardModifierMappingDst")
        }
    }
}

def array-node [entries: list] {
    el "array" ($entries | each {|e|
        el "dict" [
            (el "key" (leaf "HIDKeyboardModifierMappingDst"))
            (el "integer" (leaf ($e.dst | into string)))
            (el "key" (leaf "HIDKeyboardModifierMappingSrc"))
            (el "integer" (leaf ($e.src | into string)))
        ]
    })
}

def set-array [doc: record, arr_node: record] {
    let dict = ($doc.content | where {|n| $n.tag == "dict"} | first)
    let idx = (key-index $dict $KEY)
    let content = if ($idx | is-empty) {
        $dict.content | append (el "key" (leaf $KEY)) | append $arr_node
    } else {
        $dict.content | update ($idx + 1) $arr_node
    }
    $doc | update content.0.content $content
}

def upsert-right-ctrl [entries: list, dst: int] {
    let matches = ($entries | enumerate | where {|it| $it.item.src == $RIGHT_CTRL})
    if ($matches | is-empty) {
        $entries | append {src: $RIGHT_CTRL, dst: $dst}
    } else {
        $entries | update $matches.0.index {|e| {src: $RIGHT_CTRL, dst: $dst}}
    }
}

def find-file [] {
    let dir = ([$nu.home-dir "Library" "Preferences" "ByHost"] | path join)
    let candidates = (glob ($dir | path join ".GlobalPreferences.*.plist"))
    if ($candidates | length) == 1 {
        return ($candidates | first)
    }
    let uuid = (try {
        ^/usr/sbin/ioreg -rd1 -c IOPlatformExpertDevice
        | lines
        | parse --regex '"IOPlatformUUID" = "(?<uuid>[^"]+)"'
        | get uuid
        | first
    } catch { "" })
    let candidate = ($dir | path join $".GlobalPreferences.($uuid).plist")
    if $candidate in $candidates {
        return $candidate
    }
    error make {msg: "No ByHost global preferences file found."}
}

def load-doc [file: string] {
    ^plutil -convert xml1 -o - $file | from xml --allow-dtd
}

def reload-cfprefsd [] {
    do -i {
        ps | where name == "cfprefsd" and user == $env.USER | get pid | kill -q ...$in
    }
}

def save-doc [doc: record, file: string] {
    let tmp = (mktemp)
    try {
        let xml = ($XML_HEADER + ($doc | to xml) + "\n")
        $xml | save -f $tmp
        ^plutil -convert binary1 $tmp
        cp -f $file $"($file).bak"
        cp -f $tmp $file
        reload-cfprefsd
    } finally {
        rm -f $tmp
    }
}

def load-state [file: string] {
    let doc = (load-doc $file)
    let arr = (mapping-array $doc)
    {
        doc: $doc
        entries: (if ($arr | is-empty) { [] } else { entries-from-array $arr })
    }
}

def show-mappings [] {
    let state = (load-state (find-file))
    $state.entries | each {|e|
        {
            page: (if (on-kbd-page $e.src) { "keyboard" } else { "vendor" })
            from: (usage-name $e.src)
            to: (usage-name $e.dst)
            src: $e.src
            dst: $e.dst
        }
    }
}

def apply [mode: string, dst: int] {
    let file = (find-file)
    let state = (load-state $file)
    let kept = ($state.entries | where {|e| on-kbd-page $e.src})
    let new_doc = (set-array $state.doc (array-node (upsert-right-ctrl $kept $dst)))
    save-doc $new_doc $file
    print ("Updated " + $KEY + " (Right Ctrl -> " + $mode + ")")
    print "Unplug and replug the keyboard to apply."
}

export def show [] { show-mappings }
export def option [] { apply "option" $LEFT_ALT }
export def control [] { apply "control" $RIGHT_CTRL }
export def capslock [] { apply "capslock" $CAPSLOCK }

export def main [command?: string] {
    match $command {
        "option" => (option)
        "control" => (control)
        "capslock" => (capslock)
        "show" => (show)
        _ => (print -e $USAGE)
    }
}
