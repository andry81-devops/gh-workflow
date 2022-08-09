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
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-curl-workflow.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-tacklelib-workflow.sh"


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

current_date_time_utc="$(date --utc +%FT%TZ)"

# on exit handler
tkl_push_trap 'gh_flush_print_buffers; gh_prepend_changelog_file' EXIT

gh_print_notice_and_write_to_changelog_text_ln "current date/time: $current_date_time_utc" "$current_date_time_utc:"

current_date_utc="${current_date_time_utc/%T*}"

# exit with non 0 code if nothing is changed
IFS=$'\n' read -r -d '' last_replies last_views <<< "$(jq -c -r ".replies,.views" $stats_json)"

# CAUTION:
#   Prevent of invalid values spread if upstream user didn't properly commit completely correct json file or didn't commit at all.
#
jq_fix_null \
  last_replies:0 \
  last_views:0

# with check on integer value
[[ -z "$last_replies" || -n "${last_replies//[0-9]/}" ]] && last_replies=0
[[ -z "$last_views" || -n "${last_views//[0-9]/}" ]] && last_views=0

if [[ -z "$TEMP_DIR" ]]; then # otherwise use exterenal TEMP_DIR
  TEMP_DIR="$(mktemp -d)"

  tkl_push_trap 'rm -rf "$TEMP_DIR"' EXIT
fi

tkl_push_trap 'curl_print_response_if_error "$TEMP_DIR/response.txt"' EXIT

# CAUTION:
#   The `sed` has to be used to ignore blank lines by replacing `CR` by `LF`.
#   This is required for uniform parse the curl output in both verbose or non verbose mode.
#
if eval curl $curl_flags -o "\$TEMP_DIR/response.txt" "\$topic_query_url" 2>&1 | tee "$TEMP_DIR/response-stderr.txt" | sed -E 's/\r([^\n])/\n\1/g' | grep -P '^(?:  [% ] |(?:  |  \d|\d\d)\d |[<>] )'; then
  echo '---'
else
  echo '---'

  if [[ -s "$TEMP_DIR/response-stderr.txt" ]]; then
    echo "$(<"$TEMP_DIR/response-stderr.txt")"
    echo '---'
  fi

  gh_enable_print_buffering

  (( ! CONTINUE_ON_INVALID_INPUT )) && exit 255
fi

# check on empty
if [[ ! -s "$TEMP_DIR/response.txt" ]]; then
  if [[ -s "$TEMP_DIR/response-stderr.txt" ]]; then
    echo "$(<"$TEMP_DIR/response-stderr.txt")"
    echo '---'
  fi

  gh_enable_print_buffering

  (( ! CONTINUE_ON_INVALID_INPUT )) && exit 255
fi

replies="$(sed -rn "$replies_sed_regexp" "$TEMP_DIR/response.txt")"
views="$(sed -rn "$views_sed_regexp" "$TEMP_DIR/response.txt")"

# stats between previos/next script execution (dependent to the pipeline scheduler times)
stats_prev_exec_replies_inc=0
stats_prev_exec_views_inc=0

if [[ -n "$replies" ]]; then
  (( last_replies < replies )) && (( stats_prev_exec_replies_inc = replies - last_replies ))
fi
if [[ -n "$views" ]]; then
  (( last_views < views )) && (( stats_prev_exec_views_inc = views - last_views ))
fi

gh_print_notice_and_write_to_changelog_text_bullet_ln "query file size: $(stat -c%s "$TEMP_DIR/response.txt")"

gh_print_notice_and_write_to_changelog_text_bullet_ln "accum prev / next / diff: re vi: $last_replies $last_views / ${replies:-"-"} ${views:-"-"} / +$stats_prev_exec_replies_inc +$stats_prev_exec_views_inc"

# with check on integer value
[[ -z "$replies" || -n "${replies//[0-9]/}" ]] && replies=$last_replies
[[ -z "$views" || -n "${views//[0-9]/}" ]] && views=$last_views

# stats between last date and previous date (independent to the pipeline scheduler times)
replies_saved=0
views_saved=0

timestamp_date_utc="${current_date_time_utc/%T*}"
timestamp_year_utc="${timestamp_date_utc/%-*}"
timestamp_year_dir="$stats_by_year_dir/$timestamp_year_utc"
year_date_json="$timestamp_year_dir/$timestamp_date_utc.json"

if [[ -f "$year_date_json" ]]; then
  IFS=$'\n' read -r -d '' replies_saved views_saved <<< \
    "$(jq -c -r ".replies,.views" $year_date_json)"

  # CAUTION:
  #   Prevent of invalid values spread if upstream user didn't properly commit completely correct json file or didn't commit at all.
  #
  jq_fix_null \
    replies_saved:0 views_saved:0
fi

(( replies_saved += stats_prev_exec_replies_inc ))
(( views_saved += stats_prev_exec_views_inc ))

if (( replies != last_replies || views != last_views )); then
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
  \"replies\" : $replies_saved,
  \"views\" : $views_saved
}" > "$year_date_json"
fi

# continue if at least one is valid
if (( replies < last_replies || views < last_views )); then
  gh_print_warning_and_write_to_changelog_text_bullet_ln "$0: warning: replies or views is decremented." "replies or views is decremented"
fi

if (( last_replies >= replies && last_views >= views )); then
  gh_enable_print_buffering

  gh_print_warning_and_write_to_changelog_text_bullet_ln "$0: warning: nothing is changed, no new board replies/views." "nothing is changed, no new board replies/views"

  (( ! CONTINUE_ON_EMPTY_CHANGES )) && exit 255
fi

commit_message_date_time_prefix="$current_date_utc"

if (( ENABLE_COMMIT_MESSAGE_DATE_WITH_TIME )); then
  commit_message_date_time_prefix="${current_date_time_utc%:*Z}Z"
fi

# return output variables

# CAUTION:
#   We must explicitly state the statistic calculation time in the script, because
#   the time taken from the input and the time set to commit changes ARE DIFFERENT
#   and may be shifted to the next day.
#
gh_set_env_var STATS_DATE_UTC                     "$current_date_utc"
gh_set_env_var STATS_DATE_TIME_UTC                "$current_date_time_utc"

gh_set_env_var STATS_PREV_EXEC_REPLIES_INC        "$stats_prev_exec_replies_inc"
gh_set_env_var STATS_PREV_EXEC_VIEWS_INC          "$stats_prev_exec_views_inc"

gh_set_env_var COMMIT_MESSAGE_DATE_TIME_PREFIX    "$commit_message_date_time_prefix"

gh_set_env_var COMMIT_MESSAGE_PREFIX              "re vi: +$stats_prev_exec_replies_inc +$stats_prev_exec_views_inc / $replies_saved $views_saved"
gh_set_env_var COMMIT_MESSAGE_SUFFIX              "$commit_msg_entity"

tkl_set_return
