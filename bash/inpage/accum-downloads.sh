#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

[[ -z "$GH_WORKFLOW_ROOT" ]] && {
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
}

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?

tkl_include "$GH_WORKFLOW_ROOT/bash/github/init-basic-workflow.sh" || tkl_abort_include
tkl_include "$GH_WORKFLOW_ROOT/bash/github/init-stats-workflow.sh" || tkl_abort_include
tkl_include "$GH_WORKFLOW_ROOT/bash/github/init-jq-workflow.sh" || tkl_abort_include


[[ -z "$stat_entity_path" ]] && {
  gh_print_error "$0: error: \`stat_entity_path\` variable is not defined."
  exit 255
}

[[ -z "$query_url" ]] && {
  gh_print_error "$0: error: \`query_url\` variable is not defined."
  exit 255
}

[[ -z "$downloads_sed_regexp" ]] && {
  gh_print_error "$0: error: \`downloads_sed_regexp\` variable is not defined."
  exit 255
}

[[ -z "$stats_by_year_dir" ]] && stats_by_year_dir="$stats_dir/by_year"
[[ -z "$stats_json" ]] && stats_json="$stats_dir/latest.json"

current_date_time_utc=$(date --utc +%FT%TZ)

# on exit handler
builtin trap "tkl_set_error $?; gh_flush_print_buffers; gh_prepend_changelog_file; builtin trap - EXIT; tkl_set_return $tkl__last_error;" EXIT

gh_print_notice_and_changelog_text_ln "current date/time: $current_date_time_utc" "$current_date_time_utc:"

current_date_utc=${current_date_time_utc/%T*}

# exit with non 0 code if nothing is changed
IFS=$'\n' read -r -d '' last_downloads <<< "$(jq -c -r ".downloads" $stats_json)"

# CAUTION:
#   Prevent of invalid values spread if upstream user didn't properly commit completely correct json file or didn't commit at all.
#
jq_fix_null \
  last_downloads:0

TEMP_DIR=$(mktemp -d)

trap "rm -rf \"$TEMP_DIR\"" EXIT HUP INT QUIT

eval curl $curl_flags "\$query_url" > "$TEMP_DIR/query.txt" || {
  gh_enable_print_buffering

  (( ! CONTINUE_ON_INVALID_INPUT )) && exit $?
}

downloads=$(sed -rn "$downloads_sed_regexp" "$TEMP_DIR/query.txt")

# stats between previos/next script execution (dependent to the pipeline scheduler times)
stats_prev_exec_downloads_inc=0

if [[ -n "$downloads" ]]; then
  (( last_downloads < downloads )) && (( stats_prev_exec_downloads_inc=downloads-last_downloads ))
fi

gh_print_notice_and_changelog_text_bullet_ln "query file size: $(stat -c%s "$TEMP_DIR/query.txt")"

gh_print_notice_and_changelog_text_bullet_ln "json prev / next / diff: dl: $last_downloads / ${downloads:-'-'} / +$stats_prev_exec_downloads_inc"

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
  jq_fix_null \
    downloads_saved:0 \
    downloads_prev_day_inc_saved:0
fi

(( stats_prev_day_downloads_inc+=downloads_prev_day_inc_saved+stats_prev_exec_downloads_inc ))

gh_print_notice_and_changelog_text_bullet_ln "prev day diff: dl: +$stats_prev_day_downloads_inc"

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
  gh_print_warning_and_changelog_text_bullet_ln "$0: warning: downloads is decremented for \`$stat_entity_path\`." "downloads is decremented for \`$stat_entity_path\`"
fi

if (( last_downloads >= downloads )); then
  gh_enable_print_buffering

  gh_print_warning_and_changelog_text_bullet_ln "$0: warning: nothing is changed for \`$stat_entity_path\`, no new downloads." "nothing is changed for \`$stat_entity_path\`, no new downloads"

  (( ! CONTINUE_ON_EMPTY_CHANGES )) && exit 255
fi

# return output variables

# CAUTION:
#   We must explicitly state the statistic calculation time in the script, because
#   the time taken from a script and the time set to commit changes ARE DIFFERENT
#   and may be shifted to the next day.
#
gh_set_env_var STATS_DATE_UTC                     "$current_date_utc"
gh_set_env_var STATS_DATE_TIME_UTC                "$current_date_time_utc"

gh_set_env_var STATS_PREV_EXEC_DOWNLOADS_INC      "$stats_prev_exec_downloads_inc"

gh_set_env_var STATS_PREV_DAY_DOWNLOADS_INC       "$stats_prev_day_downloads_inc"

gh_set_env_var COMMIT_MESSAGE_SUFFIX              " | dl: +$stats_prev_day_downloads_inc"

tkl_set_return
