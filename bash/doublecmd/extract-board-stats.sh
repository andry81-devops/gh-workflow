#!/bin/bash

[[ -z "$traffic_doublecmd_board_stats_json" ]] && traffic_doublecmd_board_stats_json='traffic/doublecmd_board_stats.json'
[[ -z "$topic_query_url" ]] && {
  echo "$0: error: \`topic_query_url\` variable is not defined."
  exit 255
} >&2

TEMP_DIR=$(mktemp -d)

trap "rm -rf \"$TEMP_DIR\"" EXIT HUP INT QUIT

curl "${topic_query_url}" > "$TEMP_DIR/query.txt" || exit $?

replies=$(sed -rn 's/.*class="posts"[^0-9]*([0-9.]+).*/\1/p' "$TEMP_DIR/query.txt")
views=$(sed -rn 's/.*class="views"[^0-9]*([0-9.]+).*/\1/p' "$TEMP_DIR/query.txt")

[[ -n "$replies" && -n "$views" ]] && cat << EOF > $traffic_doublecmd_board_stats_json
{
  "timestamp" : "$(date --utc +%FT%TZ)",
  "replies" : $replies,
  "views" : $views
}
EOF
