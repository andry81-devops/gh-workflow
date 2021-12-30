#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

function print_error()
{
  echo "$*" >&2
  [[ -n "$GITHUB_ACTIONS" ]] && echo "::error ::$*"
}

function print_warning()
{
  echo "$*" >&2
  [[ -n "$GITHUB_ACTIONS" ]] && echo "::warning ::$*"
}

function print_notice()
{
  echo "$*"
  [[ -n "$GITHUB_ACTIONS" ]] && echo "::notice ::$*"
}

function set_env_var()
{
  [[ -n "$GITHUB_ACTIONS" ]] && echo "$1=$2" >> $GITHUB_ENV
}

[[ -z "$stats_dir" ]] && {
  print_error "$0: error: \`stats_dir\` variable is not defined."
  exit 255
} >&2

[[ -z "$stat_entity_path" ]] && {
  print_error "$0: error: \`stat_entity_path\` variable is not defined."
  exit 255
} >&2

[[ -z "$query_url" ]] && {
  print_error "$0: error: \`query_url\` variable is not defined."
  exit 255
} >&2

[[ -z "$downloads_sed_regexp" ]] && {
  print_error "$0: error: \`downloads_sed_regexp\` variable is not defined."
  exit 255
} >&2

[[ -z "$stats_by_year_dir" ]] && stats_by_year_dir="$stats_dir/by_year"
[[ -z "$stats_json" ]] && stats_json="$stats_dir/latest.json"

current_date_time_utc=$(date --utc +%FT%TZ)

# exit with non 0 code if nothing is changed
IFS=$'\n' read -r -d '' last_downloads <<< "$(jq -c -r ".downloads" $stats_json)"

TEMP_DIR=$(mktemp -d)

trap "rm -rf \"$TEMP_DIR\"" EXIT HUP INT QUIT

eval curl $curl_flags "\$query_url" > "$TEMP_DIR/query.txt" || exit $?

downloads=$(sed -rn "$downloads_sed_regexp" "$TEMP_DIR/query.txt")

(( stats_downloads_diff=downloads-last_downloads ))

print_notice "query file size: $(stat -c%s "$TEMP_DIR/query.txt")"
print_notice "downloads: prev / next / diff: $last_downloads / $downloads / $stats_downloads_diff"

[[ -z "$downloads" ]] || (( last_downloads >= downloads )) && {
  print_warning "$0: warning: nothing is changed for \`$stat_entity_path\`, no new downloads."
  exit 255
} >&2

echo "\
{
  \"timestamp\" : \"$current_date_time_utc\",
  \"downloads\" : $downloads
}" > "$stats_json"

timestamp_date_time_utc=${current_date_time_utc//:/-}
timestamp_date_utc=${timestamp_date_time_utc/%T*}
timestamp_year_utc=${timestamp_date_utc/%-*}

timestamp_year_dir="$stats_by_year_dir/$timestamp_year_utc"

[[ ! -d "$timestamp_year_dir" ]] && mkdir -p "$timestamp_year_dir"

echo "\
{
  \"timestamp\" : \"$current_date_time_utc\",
  \"downloads\" : $downloads
}" > "$timestamp_year_dir/$timestamp_date_utc.json"

# return output variables
set_env_var STATS_DOWNLOADS_DIFF  "$stats_downloads_diff"

set_env_var COMMIT_MESSAGE_SUFFIX " | dl: $stats_downloads_diff"
