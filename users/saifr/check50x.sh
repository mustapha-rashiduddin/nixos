#!/bin/sh
# check50x - check50 wrapper: guess the assignment slug from the current dir.
#
#   check50x                -> check50 cs50/problems/2024/sql/<dirname>
#   check50x .              -> same guess (also works from subdirs; walks up
#                              until it finds a *.db)
#   check50x <slug-or-url>  -> passes through verbatim (explicit slugs/git urls)
#
# Override the guess per directory name with $XDG_CONFIG_HOME/cs50/slug.map:
#   union-soldiers=cs50/problems/2019/x/union
#   mycake=custom/problempack

map=${CS50_SLUG_MAP:-${XDG_CONFIG_HOME:-$HOME/.config}/cs50/slug.map}

if [ -n "$1" ] && [ "$1" != "." ] && [ ! -e "$1" ]; then
    exec check50 "$@"
fi

if [ -n "$1" ]; then
    shift
fi

d=$PWD
while :; do
    if ls "$d"/*.db >/dev/null 2>&1; then
        break
    fi
    [ "$d" = / ] && break
    d=${d%/*}
done
name=${d##*/}

slug="cs50/problems/2024/sql/$name"
if [ -r "$map" ]; then
    mapped=$(awk -F= -v n="$name" '$1 == n {print $2; exit}' "$map")
    [ -n "$mapped" ] && slug=$mapped
fi

exec check50 "$slug" "$@"