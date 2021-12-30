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

[[ -z "$board_name" ]] && {
  print_error "$0: error: \`board_name\` variable is not defined."
  exit 255
} >&2

[[ -z "$topic_query_url" ]] && {
  print_error "$0: error: \`topic_query_url\` variable is not defined."
  exit 255
} >&2

[[ -z "$replies_sed_regexp" ]] && {
  print_error "$0: error: \`replies_sed_regexp\` variable is not defined."
  exit 255
} >&2

[[ -z "$views_sed_regexp" ]] && {
  print_error "$0: error: \`views_sed_regexp\` variable is not defined."
  exit 255
} >&2

[[ -z "$stats_by_year_dir" ]] && stats_by_year_dir="$stats_dir/by_year"
[[ -z "$stats_json" ]] && stats_json="$stats_dir/latest.json"

current_date_time_utc=$(date --utc +%FT%TZ)

# exit with non 0 code if nothing is changed
IFS=$'\n' read -r -d '' last_replies last_views <<< "$(jq -c -r ".replies,.views" $stats_json)"

TEMP_DIR=$(mktemp -d)

trap "rm -rf \"$TEMP_DIR\"" EXIT HUP INT QUIT

eval curl $curl_flags "\$topic_query_url" > "$TEMP_DIR/query.txt" || exit $?

replies=$(sed -rn "$replies_sed_regexp" "$TEMP_DIR/query.txt")
views=$(sed -rn "$views_sed_regexp" "$TEMP_DIR/query.txt")

(( stats_replies_diff=replies-last_replies ))
(( stats_views_diff=views-last_views ))

print_notice "query file size: $(stat -c%s "$TEMP_DIR/query.txt")"
print_notice "replies: prev / next / diff: $last_replies / $replies / $stats_replies_diff"
print_notice "views: prev / next / diff: $last_views / $views / $stats_views_diff"

[[ -z "$replies" || -z "$views" ]] || (( last_replies >= replies && last_views >= views )) && {
  print_warning "$0: warning: nothing is changed for \`$board_name\`, no new board replies/views."
  exit 255
} >&2

echo "\
{
  \"timestamp\" : \"$current_date_time_utc\",
  \"replies\" : $replies,
  \"views\" : $views
}" > "$stats_json"

timestamp_date_time_utc=${current_date_time_utc//:/-}
timestamp_date_utc=${timestamp_date_time_utc/%T*}
timestamp_year_utc=${timestamp_date_utc/%-*}

timestamp_year_dir="$stats_by_year_dir/$timestamp_year_utc"

[[ ! -d "$timestamp_year_dir" ]] && mkdir -p "$timestamp_year_dir"

echo "\
{
  \"timestamp\" : \"$current_date_time_utc\",
  \"replies\" : $replies,
  \"views\" : $views
}" > "$timestamp_year_dir/$timestamp_date_utc.json"

# return output variables
set_env_var STATS_REPLIES_DIFF    "$stats_replies_diff"
set_env_var STATS_VIEWS_DIFF      "$stats_views_diff"

set_env_var COMMIT_MESSAGE_SUFFIX " | re vi: $stats_replies_diff $stats_views_diff"
