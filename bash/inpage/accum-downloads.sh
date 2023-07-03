#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

if [[ -z "$GH_WORKFLOW_ROOT" ]]; then
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
fi

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?

tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-basic-workflow.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-stats-workflow.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-jq-workflow.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-curl-workflow.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-tacklelib-workflow.sh"


if [[ -z "$query_url" ]]; then
  gh_print_error_ln "$0: error: \`query_url\` variable is not defined."
  exit 255
fi

if [[ -z "$downloads_sed_regexp" ]]; then
  gh_print_error_ln "$0: error: \`downloads_sed_regexp\` variable is not defined."
  exit 255
fi

[[ -z "$stats_by_year_dir" ]] && stats_by_year_dir="$stats_dir/by_year"
[[ -z "$stats_json" ]] && stats_json="$stats_dir/latest.json"

current_date_time_utc="$(date --utc +%FT%TZ)"

current_date_utc="${current_date_time_utc/%T*}"

current_date_time_utc_sec="$(date --utc -d "${current_date_time_utc}" +%s)" # seconds from epoch to current date with time

# on exit handler
tkl_push_trap 'gh_flush_print_buffers; gh_prepend_changelog_file' EXIT

gh_print_notice_and_write_to_changelog_text_ln "current date/time: $current_date_time_utc" "$current_date_time_utc:"

if (( ENABLE_GITHUB_ACTIONS_RUN_URL_PRINT_TO_CHANGELOG )) && [[ -n "$GHWF_GITHUB_ACTIONS_RUN_URL" ]]; then
  gh_write_notice_to_changelog_text_bullet_ln \
    "GitHub Actions Run: $GHWF_GITHUB_ACTIONS_RUN_URL # $GITHUB_RUN_NUMBER"
fi

if (( ENABLE_REPO_STATS_COMMITS_URL_PRINT_TO_CHANGELOG )) && [[ -n "$GHWF_REPO_STATS_COMMITS_URL" ]]; then
  (( repo_stats_commits_url_until_date_time_utc_sec = current_date_time_utc_sec + 60 * 5 )) # +5min approximation and truncation to days

  repo_stats_commits_url_until_date_time_utc="$(date --utc -d "@$repo_stats_commits_url_until_date_time_utc_sec" +%FT%TZ)"

  repo_stats_commits_url_until_date_utc_day="${repo_stats_commits_url_until_date_time_utc/%T*}"

  gh_write_notice_to_changelog_text_bullet_ln \
    "Stats Output Repository: $GHWF_REPO_STATS_COMMITS_URL&until=$repo_stats_commits_url_until_date_utc_day"
fi

# exit with non 0 code if nothing is changed
IFS=$'\n' read -r -d '' last_downloads <<< "$(jq -c -r ".downloads" $stats_json)"

# CAUTION:
#   Prevent of invalid values spread if upstream user didn't properly commit completely correct json file or didn't commit at all.
#
jq_fix_null \
  last_downloads:0

if [[ -z "$TEMP_DIR" ]]; then # otherwise use exterenal TEMP_DIR
  TEMP_DIR="$(mktemp -d)"

  tkl_push_trap 'rm -rf "$TEMP_DIR"' EXIT
fi

tkl_push_trap 'curl_print_response_if_error "$TEMP_DIR/response.txt"' EXIT

# CAUTION:
#   The `sed` has to be used to ignore blank lines by replacing `CR` by `LF`.
#   This is required for uniform parse the curl output in both verbose or non verbose mode.
#
eval curl $curl_flags -o '"$TEMP_DIR/response.txt"' '"$query_url"' 2>&1 | tee "$TEMP_DIR/response-stderr.txt" | sed -E 's/\r([^\n])/\n\1/g' | grep -P '^(?:  [% ] |(?:  |  \d|\d\d)\d |[<>] )'
last_error=$?

echo '---'

# always print stderr unconditionally to a return code
if [[ -s "$TEMP_DIR/response-stderr.txt" ]]; then
  echo "$(<"$TEMP_DIR/response-stderr.txt")"
  echo '---'
fi

if (( last_error )); then
  gh_enable_print_buffering

  (( ! CONTINUE_ON_INVALID_INPUT )) && exit 255
fi

# check on empty
if [[ ! -s "$TEMP_DIR/response.txt" ]]; then
  gh_enable_print_buffering

  (( ! CONTINUE_ON_INVALID_INPUT )) && exit 255
fi

downloads="$(sed -rn "$downloads_sed_regexp" "$TEMP_DIR/response.txt")"

# stats between previos/next script execution (dependent to the pipeline scheduler times)
stats_prev_exec_downloads_inc=0

downloads_malformed=1

# with check on malformed value
if [[ -n "$downloads" ]]; then
  if [[ -z "${downloads//[0-9]/}" ]]; then
    downloads_malformed=0
  fi
  (( last_downloads < downloads )) && (( stats_prev_exec_downloads_inc = downloads - last_downloads ))
fi

gh_print_notice_and_write_to_changelog_text_bullet_ln "query file size: $(stat -c%s "$TEMP_DIR/response.txt")"

gh_print_notice_and_write_to_changelog_text_bullet_ln "accum prev / next / diff: dl: $last_downloads / ${downloads:-"-"} / +$stats_prev_exec_downloads_inc"

# reset on malform
(( downloads_malformed )) && downloads=$last_downloads

# stats between last date and previous date (independent to the pipeline scheduler times)
stats_last_changed_date_downloads_inc=0

downloads_saved=0

timestamp_date_utc="${current_date_time_utc/%T*}"
timestamp_year_utc="${timestamp_date_utc/%-*}"
timestamp_year_dir="$stats_by_year_dir/$timestamp_year_utc"
year_date_json="$timestamp_year_dir/$timestamp_date_utc.json"

if [[ -f "$year_date_json" ]]; then
  IFS=$'\n' read -r -d '' downloads_saved <<< \
    "$(jq -c -r ".downloads" $year_date_json)"

  # CAUTION:
  #   Prevent of invalid values spread if upstream user didn't properly commit completely correct json file or didn't commit at all.
  #
  jq_fix_null \
    downloads_saved:0
fi

(( downloads_saved += stats_prev_exec_downloads_inc ))

gh_print_notice_and_write_to_changelog_text_bullet_ln "prev exec diff: dl: +$stats_prev_exec_downloads_inc"

if (( downloads != last_downloads )); then
  echo "\
{
  \"timestamp\" : \"$current_date_time_utc\",
  \"downloads\" : $downloads
}" > "$stats_json"

  [[ ! -d "$timestamp_year_dir" ]] && mkdir -p "$timestamp_year_dir"

  echo "\
{
  \"timestamp\" : \"$current_date_time_utc\",
  \"downloads\" : $downloads_saved
}" > "$year_date_json"
fi

# continue if at least one is valid
if (( downloads < last_downloads )); then
  gh_print_warning_and_write_to_changelog_text_bullet_ln "$0: warning: downloads is decremented." "downloads is decremented"
fi

if (( last_downloads >= downloads )); then
  gh_enable_print_buffering

  if (( ! downloads_malformed )); then
    gh_print_warning_and_write_to_changelog_text_bullet_ln "$0: warning: nothing is changed, no new downloads." "nothing is changed, no new downloads"
  else
    gh_print_warning_and_write_to_changelog_text_bullet_ln "$0: warning: responce file is not valid, downloads value is malformed." "responce file is not valid, downloads value is malformed"
  fi

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

gh_set_env_var STATS_PREV_EXEC_DOWNLOADS_INC      "$stats_prev_exec_downloads_inc"

gh_set_env_var COMMIT_MESSAGE_DATE_TIME_PREFIX    "$commit_message_date_time_prefix"

gh_set_env_var COMMIT_MESSAGE_PREFIX              "dl: +$stats_prev_exec_downloads_inc / $downloads_saved"
gh_set_env_var COMMIT_MESSAGE_SUFFIX              "$commit_msg_entity"

tkl_set_return
