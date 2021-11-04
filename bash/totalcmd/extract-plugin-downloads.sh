#!/bin/bash

function print_error()
{
  [[ -n "$write_error_to_file" ]] && echo "$*" >> "$write_error_to_file"
  echo "$*" >&2
}

function print_warning()
{
  [[ -n "$write_warning_to_file" ]] && echo "$*" >> "$write_warning_to_file"
  echo "$*" >&2
}

[[ -z "$traffic_downloads_dir" ]] && traffic_downloads_dir='traffic/downloads/plugin'
[[ -z "$traffic_downloads_by_year_dir" ]] && traffic_downloads_by_year_dir="$traffic_downloads_dir/by_year"
[[ -z "$traffic_downloads_json" ]] && traffic_downloads_json="$traffic_downloads_dir/latest.json"
[[ -z "$plugin_path" ]] && {
  print_error "$0: error: \`$plugin_path\` variable is not defined."
  exit 255
} >&2

current_date_time_utc=$(date --utc +%FT%TZ)

# exit with non 0 code if nothing is changed
IFS=$'\n' read -r -d '' last_downloads <<< "$(jq -c -r ".downloads" $traffic_downloads_json)"

TEMP_DIR=$(mktemp -d)

trap "rm -rf \"$TEMP_DIR\"" EXIT HUP INT QUIT

curl "http://totalcmd.net/${plugin_path}.html" > "$TEMP_DIR/query.txt" || exit $?

downloads=$(sed -rn 's/.*Downloaded:[^0-9]*([0-9.]+).*/\1/p' "$TEMP_DIR/query.txt")

[[ -z "$downloads" ]] || (( last_downloads >= downloads )) && {
  print_warning "$0: warning: \`$plugin_path\` nothing is changed, no new downloads."
  exit 255
} >&2

echo "\
{
  \"timestamp\" : \"$current_date_time_utc\",
  \"downloads\" : $downloads
}" > "$traffic_downloads_json"

timestamp_date_time_utc=${current_date_time_utc//:/-}
timestamp_date_utc=${timestamp_date_time_utc/%T*}
timestamp_year_utc=${timestamp_date_utc/%-*}

timestamp_year_dir="$traffic_downloads_by_year_dir/$timestamp_year_utc"

[[ ! -d "$timestamp_year_dir" ]] && mkdir -p "$timestamp_year_dir"

echo "\
{
  \"timestamp\" : \"$current_date_time_utc\",
  \"downloads\" : $downloads
}" > "$timestamp_year_dir/$timestamp_date_utc.json"
