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

[[ -z "$traffic_doublecmd_board_stats_dir" ]] && traffic_doublecmd_board_stats_dir='traffic/board/doublecmd'
[[ -z "$traffic_doublecmd_board_stats_by_year_dir" ]] && traffic_doublecmd_board_stats_by_year_dir="$traffic_doublecmd_board_stats_dir/by_year"
[[ -z "$traffic_doublecmd_board_stats_json" ]] && traffic_doublecmd_board_stats_json="$traffic_doublecmd_board_stats_dir/latest.json"
[[ -z "$topic_query_url" ]] && {
  print_error "$0: error: \`topic_query_url\` variable is not defined."
  exit 255
} >&2

current_date_time_utc=$(date --utc +%FT%TZ)

# exit with non 0 code if nothing is changed
IFS=$'\n' read -r -d '' last_replies last_views <<< "$(jq -c -r ".replies,.views" $traffic_doublecmd_board_stats_json)"

TEMP_DIR=$(mktemp -d)

trap "rm -rf \"$TEMP_DIR\"" EXIT HUP INT QUIT

curl "${topic_query_url}" > "$TEMP_DIR/query.txt" || exit $?

replies=$(sed -rn 's/.*class="posts"[^0-9]*([0-9.]+).*/\1/p' "$TEMP_DIR/query.txt")
views=$(sed -rn 's/.*class="views"[^0-9]*([0-9.]+).*/\1/p' "$TEMP_DIR/query.txt")

[[ -z "$replies" || -z "$views" ]] || (( last_replies >= replies && last_views >= views )) && {
  print_warning "$0: warning: nothing is changed, no new doublecmd board replies/views."
  exit 255
} >&2

echo "\
{
  \"timestamp\" : \"$current_date_time_utc\",
  \"replies\" : $replies,
  \"views\" : $views
}" > "$traffic_doublecmd_board_stats_json"

timestamp_date_time_utc=${current_date_time_utc//:/-}
timestamp_date_utc=${timestamp_date_time_utc/%T*}
timestamp_year_utc=${timestamp_date_utc/%-*}

timestamp_year_dir="$traffic_doublecmd_board_stats_by_year_dir/$timestamp_year_utc"

[[ ! -d "$timestamp_year_dir" ]] && mkdir -p "$timestamp_year_dir"

echo "\
{
  \"timestamp\" : \"$current_date_time_utc\",
  \"replies\" : $replies,
  \"views\" : $views
}" > "$timestamp_year_dir/$timestamp_date_utc.json"
