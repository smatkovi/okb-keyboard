#! /bin/bash
# patch management for keyboard qml files

cd "$(dirname "$0")"
release="$(ssu re 2>/dev/null | sed 's/^.*:\ *//')"

FILES="
plugin /usr/lib/maliit/plugins/jolla-keyboard.qml plugin/okboard.qml
base /usr/share/maliit/plugins/com/jolla/KeyboardBase.qml qml/eu/cpbm/okboard/CurveKeyboardBase.qml
"

die() { echo "ERR: $*" ; exit 1 ; }

usage() {
    echo "usage: $(basename "$0") <command> [<args>]"
    echo "commands"
    echo "  create:  create patch files from installed jolla keyboard files to working"
    echo "           okboard files"
    echo "  apply:   apply patch (argument is release version) to currently installed"
    echo "           jolla keyboard files and replace included source code version"
    exit 255
}

create() {
    echo "$FILES" | (
	while read id os mine ; do
	    [ -n "$id" ] || continue
	    ( set -x ; diff -u "$os" "$mine" > "patches/${id}-${release}.diff" )
	done
    )
    find patches/ -name "*${release}.diff" | xargs ls -la
}

apply() {
    local release="$1"
    [ -n "$release" ] || usage
    err=
    echo "$FILES" | (
	while read id os mine ; do
	    [ -n "$id" ] || continue
	    [ -f "patches/${id}-${release}.diff" ] || die "No patch for release '${release}'"
	    rm -f "$mine.rej" "$mine.orig"
	    cp -vf "$os" "$mine"
	    patch "$mine" "patches/${id}-${release}.diff" || err=1
	done
	[ -n "$err" ] && echo "### Patch failed, check for .rej files !"
    )
}


case "$1" in
    create) create ;;
    apply) apply "$2" ;;
    *) usage ;;
esac
