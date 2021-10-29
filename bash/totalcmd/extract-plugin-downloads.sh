#!/bin/bash

[[ -z "$traffic_totalcmd_dl_json" ]] && traffic_totalcmd_dl_json='traffic/totalcmd_dl.json'
[[ -z "$plugin_path" ]] && {
  echo "$0: error: \`plugin_path\` variable is not defined."
  exit 255
} >&2

# exit with non 0 code if nothing is changed
IFS=$'\n' read -r -d '' last_downloads <<< "$(jq -c -r ".downloads" $traffic_totalcmd_dl_json)"

TEMP_DIR=$(mktemp -d)

trap "rm -rf \"$TEMP_DIR\"" EXIT HUP INT QUIT

curl "http://totalcmd.net/${plugin_path}.html" > "$TEMP_DIR/query.txt" || exit $?

downloads=$(sed -rn 's/.*Downloaded:[^0-9]*([0-9.]+).*/\1/p' "$TEMP_DIR/query.txt")

[[ -n "$downloads" ]] && (( last_downloads < downloads )) && {
  cat << EOF > $traffic_totalcmd_dl_json
{
  "timestamp" : "$(date --utc +%FT%TZ)",
  "downloads" : $downloads
}
EOF
exit $?
}

echo "$0: warning: \`plugin_path\` nothing is changed, no new downloads."
exit 255
