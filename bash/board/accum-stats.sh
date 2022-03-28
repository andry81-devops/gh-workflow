#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

[[ -z "$GH_WORKFLOW_ROOT" ]] && {
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
}

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?

tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-basic-workflow.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-stats-workflow.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-jq-workflow.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-tacklelib-workflow.sh"


[[ -z "$board_name" ]] && {
  gh_print_error_ln "$0: error: \`board_name\` variable is not defined."
  exit 255
}

[[ -z "$topic_query_url" ]] && {
  gh_print_error_ln "$0: error: \`topic_query_url\` variable is not defined."
  exit 255
}

[[ -z "$replies_sed_regexp" ]] && {
  gh_print_error_ln "$0: error: \`replies_sed_regexp\` variable is not defined."
  exit 255
}

[[ -z "$views_sed_regexp" ]] && {
  gh_print_error_ln "$0: error: \`views_sed_regexp\` variable is not defined."
  exit 255
}

[[ -z "$stats_by_year_dir" ]] && stats_by_year_dir="$stats_dir/by_year"
[[ -z "$stats_json" ]] && stats_json="$stats_dir/latest.json"

current_date_time_utc=$(date --utc +%FT%TZ)

# on exit handler
tkl_push_trap 'gh_flush_print_buffers; gh_prepend_changelog_file' EXIT

gh_print_notice_and_changelog_text_ln "current date/time: $current_date_time_utc" "$current_date_time_utc:"

current_date_utc=${current_date_time_utc/%T*}

# exit with non 0 code if nothing is changed
IFS=$'\n' read -r -d '' last_replies last_views <<< "$(jq -c -r ".replies,.views" $stats_json)"

# CAUTION:
#   Prevent of invalid values spread if upstream user didn't properly commit completely correct json file or didn't commit at all.
#
jq_fix_null \
  last_replies:0 \
  last_views:0

TEMP_DIR=$(mktemp -d)

tkl_push_trap 'rm -rf "$TEMP_DIR"' EXIT

eval curl $curl_flags "\$topic_query_url" > "$TEMP_DIR/query.txt" || {
  gh_enable_print_buffering

  (( ! CONTINUE_ON_INVALID_INPUT )) && exit $?
}

replies=$(sed -rn "$replies_sed_regexp" "$TEMP_DIR/query.txt")
views=$(sed -rn "$views_sed_regexp" "$TEMP_DIR/query.txt")

# stats between previos/next script execution (dependent to the pipeline scheduler times)
stats_prev_exec_replies_inc=0
stats_prev_exec_views_inc=0

if [[ -n "$replies" ]]; then
  (( last_replies < replies )) && (( stats_prev_exec_replies_inc=replies-last_replies ))
fi
if [[ -n "$views" ]]; then
  (( last_views < views )) && (( stats_prev_exec_views_inc=views-last_views ))
fi

gh_print_notice_and_changelog_text_bullet_ln "query file size: $(stat -c%s "$TEMP_DIR/query.txt")"

gh_print_notice_and_changelog_text_bullet_ln "json prev / next / diff: re vi: $last_replies $last_views / ${replies:-"-"} ${views:-"-"} / +$stats_prev_exec_replies_inc +$stats_prev_exec_views_inc"

# with check on integer value
[[ -z "$replies" || -n "${replies//[0-9]/}" ]] && replies=0
[[ -z "$views" || -n "${views//[0-9]/}" ]] && views=0

# stats between last change in previous/next day (independent to the pipeline scheduler times)
stats_prev_day_replies_inc=0
stats_prev_day_views_inc=0

replies_saved=0
views_saved=0
replies_prev_day_inc_saved=0
views_prev_day_inc_saved=0

timestamp_date_utc=${current_date_time_utc/%T*}
timestamp_year_utc=${timestamp_date_utc/%-*}
timestamp_year_dir="$stats_by_year_dir/$timestamp_year_utc"
year_date_json="$timestamp_year_dir/$timestamp_date_utc.json"

if [[ -f "$year_date_json" ]]; then
  IFS=$'\n' read -r -d '' replies_saved views_saved replies_prev_day_inc_saved views_prev_day_inc_saved <<< \
    "$(jq -c -r ".replies,.views,.replies_prev_day_inc,.views_prev_day_inc" $year_date_json)"

  # CAUTION:
  #   Prevent of invalid values spread if upstream user didn't properly commit completely correct json file or didn't commit at all.
  #
  jq_fix_null \
    replies_saved:0 views_saved:0 \
    replies_prev_day_inc_saved:0 views_prev_day_inc_saved:0
fi

(( stats_prev_day_replies_inc+=replies_prev_day_inc_saved+stats_prev_exec_replies_inc ))
(( stats_prev_day_views_inc+=views_prev_day_inc_saved+stats_prev_exec_views_inc ))

gh_print_notice_and_changelog_text_bullet_ln "prev day diff: re vi: +$stats_prev_day_replies_inc +$stats_prev_day_views_inc"

if (( replies != replies_saved || views != views_saved )); then
  echo "\
{
  \"timestamp\" : \"$current_date_time_utc\",
  \"replies\" : $replies,
  \"views\" : $views
}" > "$stats_json"

  [[ ! -d "$timestamp_year_dir" ]] && mkdir -p "$timestamp_year_dir"

  echo "\
{
  \"timestamp\" : \"$current_date_time_utc\",
  \"replies\" : $replies,
  \"replies_prev_day_inc\" : $stats_prev_day_replies_inc,
  \"views\" : $views,
  \"views_prev_day_inc\" : $stats_prev_day_views_inc
}" > "$year_date_json"
fi

# continue if at least one is valid
if (( replies < last_replies || views < last_views )); then
  gh_print_warning_and_changelog_text_bullet_ln "$0: warning: replies or views is decremented for \`$board_name\`." "replies or views is decremented for \`$board_name\`"
fi

if (( last_replies >= replies && last_views >= views )); then
  gh_enable_print_buffering

  gh_print_warning_and_changelog_text_bullet_ln "$0: warning: nothing is changed for \`$board_name\`, no new board replies/views." "nothing is changed for \`$board_name\`, no new board replies/views"

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

gh_set_env_var STATS_PREV_EXEC_REPLIES_INC        "$stats_prev_exec_replies_inc"
gh_set_env_var STATS_PREV_EXEC_VIEWS_INC          "$stats_prev_exec_views_inc"

gh_set_env_var STATS_PREV_DAY_REPLIES_INC         "$stats_prev_day_replies_inc"
gh_set_env_var STATS_PREV_DAY_VIEWS_INC           "$stats_prev_day_views_inc"

gh_set_env_var COMMIT_MESSAGE_SUFFIX              " | re vi: +$stats_prev_day_replies_inc +$stats_prev_day_views_inc"

tkl_set_return
