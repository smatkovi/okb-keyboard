#! /bin/bash
# patch management for Okboard QML files
#
# this script will be run by ash busybox shell during RPM installation
# so we have to avoid some bashisms

set -euo pipefail

cd "$(dirname "$0")"
current_release="$(ssu re 2>/dev/null | sed 's/^.*:\ *//')"

LIB="$(rpm --eval '%{_libdir}')"

# format is patch name, jolla keyboard file, path in source code, okboard target file path
FILES="
plugin ${LIB}/maliit/plugins/jolla-keyboard.qml plugin/okboard.qml ${LIB}/maliit/plugins/okboard-plugin-patch.qml
base /usr/share/maliit/plugins/com/jolla/KeyboardBase.qml qml/eu/cpbm/okboard/CurveKeyboardBasePatch.qml /usr/share/maliit/plugins/eu/cpbm/okboard/CurveKeyboardBasePatch.qml
"

ROOT=

FILES_ID="$(echo "$FILES" | awk '{ print $1 }' | grep '.')"

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
    local ok=1 id
    for id in $FILES_ID ; do
        set $(echo "$FILES" | grep "^$id ")
        local os="$2" mine="$3"
	local patch="patches/${id}-${current_release}.diff"
	if [ ! -f "$patch" ] ; then
	    ok=
	    echo "Missing file: $patch"
	else
            local expected="$(tail -n +3 "$patch")"
            local current="$(diff -u "$os" "$mine" | tail -n +3)"
            if [ "$expected" != "$current" ] ; then
	        ok=
	        echo "Mismatching patch: $patch"
	    fi
        fi
    done
    [ -n "$ok" ] || die "Patch files are not up to date"
    echo "OK"
}

create() {
    local id
    for id in $FILES_ID ; do
        set $(echo "$FILES" | grep "^$id ")
        local os="$2" mine="$3"
	mydiff -u "$os" "$mine" > "patches/${id}-${current_release}.diff"
    done
    find patches/ -name "*${current_release}.diff" | xargs ls -la
}

apply() {
    local release="$1"
    [ -n "$release" ] || usage
    echo "Applying patch for release $release ..."
    local id err=
    for id in $FILES_ID ; do
        set $(echo "$FILES" | grep "^$id ")
        local os="$2" mine="$3" prod="$4"
	[ -f "patches/${id}-${release}.diff" ] || { echo "No patch for release '${release}'" ; return 1 ; }
        if [ -n "$ROOT" ] ; then target="$prod" ; else target="$mine" ; fi
        [ -w "$(dirname "$target")/." ] || dir "Target not writable: $target"
	rm -f "$target.rej" "$target.orig"
	cp -vf "$os" "$target"
	patch "$target" "patches/${id}-${release}.diff" || err=1
    done
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
