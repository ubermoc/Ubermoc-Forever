#!/bin/sh
# Watches the saved variables of both games and prints the auto test summary every time
# the game writes them (each /reload or logout).
#   tools/watch.sh          keep watching (Ctrl+C stops)
#   tools/watch.sh --once   print both summaries now and exit (exit 1 if either got worse)
#   add --all to list every failing check, not only new ones
# Set UBF_WOW_ROOT to use another game folder.
cd "$(dirname "$0")/.."

ROOT=${UBF_WOW_ROOT:-"$HOME/.steam/steam/steamapps/compatdata/3928805520/pfx/drive_c/Program Files (x86)/World of Warcraft"}
SV="WTF/Account/FAQJOO/SavedVariables/UbermocForever.lua"
TOC="Interface/AddOns/UbermocForever/UbermocForever.toc"
ONCE=0
ALL=""
for a in "$@"; do
    case "$a" in
        --once) ONCE=1 ;;
        --all) ALL="--all" ;;
    esac
done

summary() {
    lua tools/autotest_summary.lua "$ROOT/$1/$SV" "$1" "$ROOT/$1/$TOC" $ALL
}

mtime() {
    stat -c %Y "$ROOT/$1/$SV" 2>/dev/null || echo 0
}

if [ "$ONCE" = 1 ]; then
    status=0
    for g in _forever_ _retail_; do
        summary "$g" || { [ $? = 1 ] && status=1; }
    done
    exit $status
fi

last_forever=$(mtime _forever_)
last_retail=$(mtime _retail_)
echo "Watching saved variables in $ROOT (Ctrl+C stops)"
for g in _forever_ _retail_; do summary "$g"; done
while true; do
    sleep 2
    for g in _forever_ _retail_; do
        now=$(mtime "$g")
        if [ "$g" = _forever_ ]; then last=$last_forever; else last=$last_retail; fi
        if [ "$now" != "$last" ]; then
            sleep 1   # let the game finish writing
            now=$(mtime "$g")
            if [ "$g" = _forever_ ]; then last_forever=$now; else last_retail=$now; fi
            echo "== $(date '+%H:%M:%S') $g saved variables written"
            summary "$g"
        fi
    done
done
