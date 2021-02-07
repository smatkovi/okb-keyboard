#! /bin/bash
# patch management for Okboard QML files

set -euo pipefail

cd "$(dirname "$0")"
current_release="$(ssu re 2>/dev/null | sed 's/^.*:\ *//')"

# format is patch name, jolla keyboard file, path in source code, okboard target file path
FILES="
plugin /usr/lib/maliit/plugins/jolla-keyboard.qml plugin/okboard.qml /usr/lib/maliit/plugins/okboard-plugin-patch.qml
base /usr/share/maliit/plugins/com/jolla/KeyboardBase.qml qml/eu/cpbm/okboard/CurveKeyboardBasePatch.qml /usr/share/maliit/plugins/eu/cpbm/okboard/CurveKeyboardBasePatch.qml
"

ROOT=

die() { echo "ERR: $*" ; exit 1 ; }

usage() {
    echo "usage: $(basename "$0") <command> [<args>]"
    echo "commands"
    echo "  create:  create patch files from installed jolla keyboard files to working"
    echo "           okboard files"
    echo "  apply:   apply patch (argument is release version) to currently installed"
    echo "           jolla keyboard files and replace included source code version"
    echo "  check:   check patch and source file match for current release"
    echo "  auto:    automatically apply the right patch version"
    echo "           (with fall-back on trial and error for new OS revisions)"
    echo "  install: same as 'auto', but deploy patched files to target location"
    echo "           (script must be run as root)"
    exit 255
}

mydiff() {
    local st=
    ( set -x ; diff "$@" ) || st="$?"
    [ -z "$st" -o "$st" = 1 ] || return 1
    return 0
}

check() {
    local ok=1
    while read -r id os mine _ ; do
	[ -n "$id" ] || continue
	local patch="patches/${id}-${current_release}.diff"
	if [ ! -f "$patch" ] ; then
	    ok=
	    echo "Missing file: $patch"
	elif ! cmp <(tail -n +3 "$patch") <(mydiff -u "$os" "$mine" | tail -n +3) >/dev/null ; then
	    ok=
	    echo "Mismatching patch: $patch"
	fi
    done <<< "$FILES"
    [ -n "$ok" ] || die "Patch files are not up to date"
    echo "OK"
}

create() {
    while read -r id os mine _ ; do
	[ -n "$id" ] || continue
	mydiff -u "$os" "$mine" > "patches/${id}-${current_release}.diff"
    done <<< "$FILES"
    find patches/ -name "*${current_release}.diff" | xargs ls -la
}

apply() {
    local release="$1"
    [ -n "$release" ] || usage
    echo "Applying patch for release $release ..."
    err=
    while read -r id os mine prod ; do
	[ -n "$id" ] || continue
	[ -f "patches/${id}-${release}.diff" ] || { echo "No patch for release '${release}'" ; return 1 ; }
        if [ -n "$ROOT" ] ; then target="$prod" ; else target="$mine" ; fi
        [ -w "$(dirname "$target")/." ] || dir "Target not writable: $target"
	rm -f "$target.rej" "$target.orig"
	cp -vf "$os" "$target"
	patch "$target" "patches/${id}-${release}.diff" || err=1
    done <<< "$FILES"
    [ -n "$err" ] && echo "### Patch failed, check for .rej files !" && return 1
    echo "Patch for release $release applied successfully"
}

auto() {
    if apply "$current_release" ; then return ; fi
    local release all_releases
    all_releases="$(find patches/ -type f -name 'plugin-*.diff' | sort -rn | sed -e 's/^.*plugin-//' -e 's/.diff$//' | tr '\n' ' ')"
    echo "Trying all patches in this order: $all_releases"
    for release in $all_releases ; do
        if apply "$release" ; then return ; fi
    done
    die "No relevant patch found"
}

install() {
    [ "$(id -u)" = 0 ] || die "'install' option must be called as root"
    ROOT=1
    auto
}


case "${1:-}" in
    create) create ;;
    apply) apply "$2" ;;
    check) check ;;
    install) install ;;
    auto) auto ;;
    *) usage ;;
esac

