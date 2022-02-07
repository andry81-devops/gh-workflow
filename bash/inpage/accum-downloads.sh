#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

[[ -z "$GH_WORKFLOW_ROOT" ]] && {
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
}

source "$GH_WORKFLOW_ROOT/bash/github/print-notice.sh"
source "$GH_WORKFLOW_ROOT/bash/github/print-warning.sh"
source "$GH_WORKFLOW_ROOT/bash/github/print-error.sh"

function set_env_var()
{
  [[ -n "$GITHUB_ACTIONS" ]] && echo "$1=$2" >> $GITHUB_ENV
}

[[ -z "$stats_dir" ]] && {
  print_error "$0: error: \`stats_dir\` variable is not defined."
  exit 255
}

[[ ! -d "$stats_dir" ]] && {
  print_error "$0: error: \`stats_dir\` directory is not found: \`$stats_dir\`"
  exit 255
}

[[ -n "$stats_json" && ! -f "$stats_json" ]] && {
  print_error "$0: error: \`stats_json\` file is not found: \`$stats_json\`"
  exit 255
}

[[ -z "$stat_entity_path" ]] && {
  print_error "$0: error: \`stat_entity_path\` variable is not defined."
  exit 255
}

[[ -z "$query_url" ]] && {
  print_error "$0: error: \`query_url\` variable is not defined."
  exit 255
}

[[ -z "$downloads_sed_regexp" ]] && {
  print_error "$0: error: \`downloads_sed_regexp\` variable is not defined."
  exit 255
}

[[ -z "$stats_by_year_dir" ]] && stats_by_year_dir="$stats_dir/by_year"
[[ -z "$stats_json" ]] && stats_json="$stats_dir/latest.json"

current_date_time_utc=$(date --utc +%FT%TZ)

print_notice "current date/time: $current_date_time_utc"

current_date_utc=${current_date_time_utc/%T*}

# exit with non 0 code if nothing is changed
IFS=$'\n' read -r -d '' last_downloads <<< "$(jq -c -r ".downloads" $stats_json)"

# CAUTION:
#   Prevent of invalid values spread if upstream user didn't properly commit completely correct json file or didn't commit at all.
#
[[ -z "$last_downloads" || "$last_downloads" == 'null' ]] && last_downloads=0

TEMP_DIR=$(mktemp -d)

trap "rm -rf \"$TEMP_DIR\"" EXIT HUP INT QUIT

eval curl $curl_flags "\$query_url" > "$TEMP_DIR/query.txt" || exit $?

downloads=$(sed -rn "$downloads_sed_regexp" "$TEMP_DIR/query.txt")

# stats between previos/next script execution (dependent to the pipeline scheduler times)
stats_prev_exec_downloads_inc=0

if [[ -n "$downloads" ]]; then
  (( last_downloads < downloads )) && (( stats_prev_exec_downloads_inc=downloads-last_downloads ))
fi

print_notice "query file size: $(stat -c%s "$TEMP_DIR/query.txt")"

print_notice "prev json prev / next / diff: dl: $last_downloads / ${downloads:-'-'} / +$stats_prev_exec_downloads_inc"

[[ -z "$downloads" ]] && downloads=0

# stats between last change in previous/next day (independent to the pipeline scheduler times)
stats_prev_day_downloads_inc=0

downloads_saved=0
downloads_prev_day_inc_saved=0

timestamp_date_utc=${current_date_time_utc/%T*}
timestamp_year_utc=${timestamp_date_utc/%-*}
timestamp_year_dir="$stats_by_year_dir/$timestamp_year_utc"
year_date_json="$timestamp_year_dir/$timestamp_date_utc.json"

if [[ -f "$year_date_json" ]]; then
  IFS=$'\n' read -r -d '' downloads_saved downloads_prev_day_inc_saved <<< \
    "$(jq -c -r ".downloads,.downloads_prev_day_inc" $year_date_json)"

  # CAUTION:
  #   Prevent of invalid values spread if upstream user didn't properly commit completely correct json file or didn't commit at all.
  #
  [[ -z "$downloads_saved" || "$downloads_saved" == 'null' ]] && downloads_saved=0
  [[ -z "$downloads_prev_day_inc_saved" || "$downloads_prev_day_inc_saved" == 'null' ]] && downloads_prev_day_inc_saved=0
fi

(( stats_prev_day_downloads_inc+=downloads_prev_day_inc_saved+stats_prev_exec_downloads_inc ))

print_notice "prev day diff: dl: +$stats_prev_day_downloads_inc"

if (( downloads != downloads_saved )); then
  echo "\
{
  \"timestamp\" : \"$current_date_time_utc\",
  \"downloads\" : $downloads
}" > "$stats_json"

  [[ ! -d "$timestamp_year_dir" ]] && mkdir -p "$timestamp_year_dir"

  echo "\
{
  \"timestamp\" : \"$current_date_time_utc\",
  \"downloads\" : $downloads,
  \"downloads_prev_day_inc\" : $stats_prev_day_downloads_inc
}" > "$year_date_json"
fi

# continue if at least one is valid
if (( downloads < last_downloads )); then
  print_warning "$0: warning: downloads is decremented for \`$stat_entity_path\`."
fi

if (( last_downloads >= downloads )); then
  print_warning "$0: warning: nothing is changed for \`$stat_entity_path\`, no new downloads."
  exit 255
fi

# return output variables

# CAUTION:
#   We must explicitly state the statistic calculation time in the script, because
#   the time taken from a script and the time set to commit changes ARE DIFFERENT
#   and may be shifted to the next day.
#
set_env_var STATS_DATE_UTC                  "$current_date_utc"
set_env_var STATS_DATE_TIME_UTC             "$current_date_time_utc"

set_env_var STATS_PREV_EXEC_DOWNLOADS_INC   "$stats_prev_exec_downloads_inc"

set_env_var STATS_PREV_DAY_DOWNLOADS_INC    "$stats_prev_day_downloads_inc"

set_env_var COMMIT_MESSAGE_SUFFIX           " | dl: +$stats_prev_day_downloads_inc"
