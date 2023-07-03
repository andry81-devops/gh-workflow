#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

if [[ -z "$GH_WORKFLOW_ROOT" ]]; then
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
fi

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?

tkl_include_or_abort "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/traplib.sh"

tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-basic-workflow.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-stats-workflow.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-jq-workflow.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-tacklelib-workflow.sh"


if [[ -z "$stat_entity" ]]; then
  gh_print_error_ln "$0: error: \`stat_entity\` variable is not defined."
  exit 255
fi

stat_list_key="$stat_entity"

[[ -z "$stats_by_year_dir" ]] && stats_by_year_dir="$stats_dir/by_year"
[[ -z "$stats_json" ]] && stats_json="$stats_dir/latest.json"
[[ -z "$stats_accum_json" ]] && stats_accum_json="$stats_dir/latest-accum.json"

[[ -z "$commit_msg_entity" ]] && commit_msg_entity="$stat_entity"

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

# CAUTION:
#   Sometimes the json data file comes empty for some reason.
#   We must check that special case to avoid invalid accumulation!
#
IFS=$'\n' read -r -d '' count uniques stats_length <<< $(jq ".count,.uniques,.$stat_list_key|length" $stats_json)

# CAUTION:
#   Prevent of invalid values spread if upstream user didn't properly commit completely correct json file or didn't commit at all.
#
jq_fix_null \
  count:0 \
  uniques:0 \
  stats_length:0

gh_print_notice_and_write_to_changelog_text_bullet_ln "last 14d: unq all: $uniques $count"

IFS=$'\n' read -r -d '' stats_accum_timestamp_prev count_outdated_prev uniques_outdated_prev count_prev uniques_prev <<< \
  "$(jq -c -r ".timestamp,.count_outdated,.uniques_outdated,.count,.uniques" $stats_accum_json)"

# CAUTION:
#   Prevent of invalid values spread if upstream user didn't properly commit completely correct json file or didn't commit at all.
#
jq_fix_null \
  stats_accum_timestamp_prev \
  count_outdated_prev:0 \
  uniques_outdated_prev:0 \
  count_prev:0 \
  uniques_prev:0

gh_print_notice_ln "prev accum: ${stats_accum_timestamp_prev:-"-"}: outdated-unq outdated-all / unq all: $uniques_outdated_prev $count_outdated_prev / $uniques_prev $count_prev"

gh_write_notice_to_changelog_text_bullet_ln "prev accum: outdated-unq outdated-all / unq all: $uniques_outdated_prev $count_outdated_prev / $uniques_prev $count_prev"

(( ! count && ! uniques && ! stats_length )) && {
  gh_enable_print_buffering

  gh_print_error_and_write_to_changelog_text_bullet_ln "$0: error: json data is invalid or empty." "json data is invalid or empty"

  # try to request json generic response fields to print them as a notice
  IFS=$'\n' read -r -d '' json_message json_url json_documentation_url <<< $(jq ".message,.url,.documentation_url" $stats_json)

  jq_fix_null \
    json_message \
    json_url \
    json_documentation_url

  [[ -n "$json_message" ]] && gh_print_notice_and_write_to_changelog_text_bullet_ln "json generic response: message: \`$json_message\`"
  [[ -n "$json_url" ]] && gh_print_notice_and_write_to_changelog_text_bullet_ln "json generic response: url: \`$json_url\`"
  [[ -n "$json_documentation_url" ]] && gh_print_notice_and_write_to_changelog_text_bullet_ln "json generic response: documentation_url: \`$json_documentation_url\`"

  (( ! CONTINUE_ON_INVALID_INPUT )) && exit 255
}

stats_accum_timestamps=()
stats_accum_counts=()
stats_accum_uniques=()

stats_timestamp_prev_seq=""
stats_count_prev_seq=""
stats_unique_prev_seq=""

# CAUTION:
#   Statistic can has values interpolation from, for example, per hour basis to day basis, which means the edge values can fluctuate to lower levels.
#   To prevent save up lower levels of outdated values we must to calculate the min and max values per day fluctuation for all days and save the maximum instead of
#   an interpolated value for all being removed records (after 14'th day).
#
stats_accum_count_max=()
stats_accum_uniques_max=()

for i in $(jq ".$stat_list_key|keys|.[]" $stats_accum_json); do
  # CAUTION:
  #   Prevent of invalid values spread if upstream user didn't properly commit completely correct json file or didn't commit at all.
  #
  jq_is_null i && break

  IFS=$'\n' read -r -d '' timestamp count uniques count_max uniques_max <<< \
    "$(jq -c -r ".$stat_list_key[$i].timestamp,.$stat_list_key[$i].count,.$stat_list_key[$i].uniques,
        .$stat_list_key[$i].count_minmax[1],.$stat_list_key[$i].uniques_minmax[1]" $stats_accum_json)"

  # CAUTION:
  #   Prevent of invalid values spread if upstream user didn't properly commit completely correct json file or didn't commit at all.
  #
  jq_fix_null \
    count:0 \
    uniques:0

  stats_accum_timestamps[${#stats_accum_timestamps[@]}]="$timestamp"
  stats_accum_counts[${#stats_accum_counts[@]}]=$count
  stats_accum_uniques[${#stats_accum_uniques[@]}]=$uniques

  jq_fix_null \
    count_max:$count \
    uniques_max:$uniques

  stats_accum_count_max[${#stats_accum_count_max[@]}]=$count_max
  stats_accum_uniques_max[${#stats_accum_uniques_max[@]}]=$uniques_max

  stats_timestamp_prev_seq="$stats_timestamp_prev_seq|$timestamp"
  # NOTE:
  #   Use the maximum only for the edge value, even if multiple values is outdated, because only
  #   edge values has a significant interpolation distortion.
  #
  if (( i )); then
    stats_count_prev_seq="$stats_count_prev_seq|$count"
    stats_uniques_prev_seq="$stats_uniques_prev_seq|$uniques"
  else
    stats_count_prev_seq="$stats_count_prev_seq|$count_max"
    stats_uniques_prev_seq="$stats_uniques_prev_seq|$uniques_max"
  fi
done

# stats between previos/next script execution (dependent to the pipeline scheduler times)
stats_prev_exec_count_inc=0
stats_prev_exec_uniques_inc=0
stats_prev_exec_count_dec=0
stats_prev_exec_uniques_dec=0

first_stats_timestamp=""

stats_timestamps=()
stats_counts=()
stats_uniques=()

stats_timestamp_next_seq=""
stats_count_next_seq=""
stats_unique_next_seq=""

stats_count_min=()
stats_count_max=()
stats_count_dec=()
stats_count_inc=()

stats_uniques_min=()
stats_uniques_max=()
stats_uniques_dec=()
stats_uniques_inc=()

stats_changed_data_timestamps=()

stats_last_changed_date_count=0
stats_last_changed_date_uniques=0

stats_last_changed_date_count_dec=0
stats_last_changed_date_count_inc=0
stats_last_changed_date_uniques_dec=0
stats_last_changed_date_uniques_inc=0

for i in $(jq ".$stat_list_key|keys|.[]" $stats_json); do
  # CAUTION:
  #   Prevent of invalid values spread if upstream user didn't properly commit completely correct json file or didn't commit at all.
  #
  jq_is_null i && break

  IFS=$'\n' read -r -d '' timestamp count uniques <<< "$(jq -c -r ".$stat_list_key[$i].timestamp,.$stat_list_key[$i].count,.$stat_list_key[$i].uniques" $stats_json)"

  # CAUTION:
  #   Prevent of invalid values spread if upstream user didn't properly commit completely correct json file or didn't commit at all.
  #
  jq_fix_null \
    count:0 \
    uniques:0

  (( ! i )) && first_stats_timestamp="$timestamp"

  stats_timestamps[${#stats_timestamps[@]}]="$timestamp"
  stats_counts[${#stats_counts[@]}]=$count
  stats_uniques[${#stats_uniques[@]}]=$uniques

  stats_timestamp_next_seq="$stats_timestamp_next_seq|$timestamp"

  timestamp_date_utc="${timestamp/%T*}"
  timestamp_year_utc="${timestamp_date_utc/%-*}"

  timestamp_year_dir="$stats_by_year_dir/$timestamp_year_utc"
  year_date_json="$timestamp_year_dir/$timestamp_date_utc.json"

  [[ ! -d "$timestamp_year_dir" ]] && mkdir -p "$timestamp_year_dir"

  count_saved=0
  uniques_saved=0

  count_min=$count
  count_max=$count
  uniques_min=$uniques
  uniques_max=$uniques

  count_inc=0
  count_dec=0
  uniques_inc=0
  uniques_dec=0

  count_min_saved=$count
  count_max_saved=$count
  uniques_min_saved=$uniques
  uniques_max_saved=$uniques

  count_dec_saved=0
  count_inc_saved=0
  uniques_dec_saved=0
  uniques_inc_saved=0

  # calculate min/max
  if [[ -f "$year_date_json" ]]; then
    IFS=$'\n' read -r -d '' count_saved uniques_saved count_min_saved count_max_saved uniques_min_saved uniques_max_saved \
      count_dec_saved count_inc_saved uniques_dec_saved uniques_inc_saved <<< \
      "$(jq -c -r ".count,.uniques,.count_minmax[0],.count_minmax[1],.uniques_minmax[0],.uniques_minmax[1],.count_decinc[0],.count_decinc[1],.uniques_decinc[0],.uniques_decinc[1]" \
         $year_date_json)"

    # CAUTION:
    #   Prevent of invalid values spread if upstream user didn't properly commit completely correct json file or didn't commit at all.
    #
    jq_fix_null \
      count_saved:0 uniques_saved:0 \
      count_min_saved:$count_saved count_max_saved:$count_saved \
      uniques_min_saved:$uniques_saved uniques_max_saved:$uniques_saved \
      count_dec_saved:0 count_inc_saved:0 \
      uniques_dec_saved:0 uniques_inc_saved:0

    # min cleanup
    (( ! count_min_saved )) && count_min_saved=$count
    (( ! uniques_min_saved )) && uniques_min_saved=$uniques

    # sign cleanup
    (( count_inc_saved = count_inc_saved )) # remove plus sign
    if (( count_dec_saved < 0 )); then
      (( count_dec_saved = -count_dec_saved ))
    else
      (( count_dec_saved = count_dec_saved ))
    fi

    (( uniques_inc_saved = uniques_inc_saved )) # remove plus sign
    if (( uniques_dec_saved < 0 )); then
      (( uniques_dec_saved = -uniques_dec_saved ))
    else
      (( uniques_dec_saved = uniques_dec_saved ))
    fi

    (( count_max_saved > count_max )) && count_max=$count_max_saved
    (( count_min_saved < count_min )) && count_min=$count_min_saved
    (( uniques_max_saved > uniques_max )) && uniques_max=$uniques_max_saved
    (( uniques_min_saved < uniques_min )) && uniques_min=$uniques_min_saved
  fi

  # NOTE:
  #   Use the maximum only for the edge value, even if multiple values is outdated, because only
  #   edge values has a significant interpolation distortion.
  #
  if (( i )); then
    stats_count_next_seq="$stats_count_next_seq|$count"
    stats_uniques_next_seq="$stats_uniques_next_seq|$uniques"
  else
    stats_count_next_seq="$stats_count_next_seq|$count_max"
    stats_uniques_next_seq="$stats_uniques_next_seq|$uniques_max"
  fi

  stats_count_min[${#stats_count_min[@]}]=$count_min
  stats_count_max[${#stats_count_max[@]}]=$count_max
  stats_uniques_min[${#stats_uniques_min[@]}]=$uniques_min
  stats_uniques_max[${#stats_uniques_max[@]}]=$uniques_max

  (( count > count_saved )) && (( count_inc=count-count_saved ))
  (( uniques > uniques_saved )) && (( uniques_inc=uniques-uniques_saved ))

  (( count < count_saved )) && (( count_dec=count_saved-count ))
  (( uniques < uniques_saved )) && (( uniques_dec=uniques_saved-uniques ))

  (( stats_prev_exec_count_inc += count_inc ))
  (( stats_prev_exec_count_dec += count_dec ))

  (( stats_prev_exec_uniques_inc += uniques_inc ))
  (( stats_prev_exec_uniques_dec += uniques_dec ))

  # accumulate saved increment/decrement in a day
  (( count_inc += count_inc_saved ))
  (( count_dec += count_dec_saved ))
  (( uniques_inc += uniques_inc_saved ))
  (( uniques_dec += uniques_dec_saved ))

  stats_count_dec[${#stats_count_dec[@]}]=$count_dec
  stats_count_inc[${#stats_count_inc[@]}]=$count_inc
  stats_uniques_dec[${#stats_uniques_dec[@]}]=$uniques_dec
  stats_uniques_inc[${#stats_uniques_inc[@]}]=$uniques_inc

  if (( count != count_saved || uniques != uniques_saved || \
        count_min != count_min_saved || count_max != count_max_saved || \
        uniques_min != uniques_min_saved || uniques_max != uniques_max_saved )); then
    stats_changed_data_timestamps[${#stats_changed_data_timestamps[@]}]="$timestamp"

    stats_last_changed_date_count=$count
    stats_last_changed_date_uniques=$uniques

    stats_last_changed_date_count_inc=$count_inc
    stats_last_changed_date_count_dec=$count_dec
    stats_last_changed_date_uniques_inc=$uniques_inc
    stats_last_changed_date_uniques_dec=$uniques_dec

    echo "\
{
  \"timestamp\" : \"$current_date_time_utc\",
  \"count\" : $count,
  \"count_minmax\" : [ $count_min, $count_max ],
  \"count_decinc\" : [ -$count_dec, +$count_inc ],
  \"uniques\" : $uniques,
  \"uniques_minmax\" : [ $uniques_min, $uniques_max ],
  \"uniques_decinc\" : [ -$uniques_dec, +$uniques_inc ]
}" > "$year_date_json"
  fi
done

# accumulate statistic
count_outdated_next=$count_outdated_prev
uniques_outdated_next=$uniques_outdated_prev

stats_removed_dates=()

j=0
for (( i=0; i < ${#stats_accum_timestamps[@]}; i++ )); do
  if [[ -z "$first_stats_timestamp" || "${stats_accum_timestamps[i]}" < "$first_stats_timestamp" ]]; then
    # NOTE:
    #   Use the maximum only for the edge value, even if multiple values is outdated, because only
    #   edge values has a significant interpolation distortion.
    #
    if (( j )); then
      (( count_outdated_next += ${stats_accum_counts[i]} ))
      (( uniques_outdated_next += ${stats_accum_uniques[i]} ))
    else
      (( count_outdated_next += ${stats_accum_count_max[i]} ))
      (( uniques_outdated_next += ${stats_accum_uniques_max[i]} ))
    fi
    (( j++ ))

    stats_removed_dates[${#stats_removed_dates[@]}]="${stats_accum_timestamps[i]/%T*}"
  fi
done

count_next=0
uniques_next=0

for (( i=0; i < ${#stats_timestamps[@]}; i++ )); do
  # NOTE:
  #   Use the maximum only for the edge value, even if multiple values is outdated, because only
  #   edge values has a significant interpolation distortion.
  #
  if (( i )); then
    (( count_next += ${stats_counts[i]} ))
    (( uniques_next += ${stats_uniques[i]} ))
  else
    (( count_next += ${stats_count_max[i]} ))
    (( uniques_next += ${stats_uniques_max[i]} ))
  fi
done

(( count_next += count_outdated_next ))
(( uniques_next += uniques_outdated_next ))

gh_print_notice_ln "next accum: $current_date_time_utc: outdated-unq outdated-all / unq all: $uniques_outdated_next $count_outdated_next / $uniques_next $count_next"

gh_write_notice_to_changelog_text_bullet_ln "next accum: outdated-unq outdated-all / unq all: $uniques_outdated_next $count_outdated_next / $uniques_next $count_next"

gh_print_notice_and_write_to_changelog_text_bullet_ln \
  "prev exec diff / last date diff / accum: unq all: +$stats_prev_exec_uniques_inc +$stats_prev_exec_count_inc -$stats_prev_exec_uniques_dec -$stats_prev_exec_count_dec / +$stats_last_changed_date_uniques_inc +$stats_last_changed_date_count_inc -$stats_last_changed_date_uniques_dec -$stats_last_changed_date_count_dec / $stats_last_changed_date_uniques $stats_last_changed_date_count"

stats_changed_dates=()
stats_last_changed_date_utc=""

for (( i=0; i < ${#stats_changed_data_timestamps[@]}; i++ )); do
  stats_changed_data_timestamp_str="${stats_changed_data_timestamps[i]}"
  stats_last_changed_date_utc="${stats_changed_data_timestamp_str/%T*}"
  stats_changed_dates[i]="$stats_last_changed_date_utc"
done

# or use last removed date
if [[ -z "$stats_last_changed_date_utc" ]] && (( ${#stats_removed_dates[@]} )); then
  stats_last_changed_date_utc="${stats_removed_dates[${#stats_removed_dates[@]} - 1]}"
fi

if (( ENABLE_COMMIT_MESSAGE_DATE_TIME_WITH_LAST_CHANGED_DATE_OFFSET )); then
  last_changed_date_offset='+00T'

  if [[ -n "$stats_last_changed_date_utc" ]]; then
    current_date_utc_sec="$(date --utc -d "${current_date_utc}Z" +%s)"
    last_changed_date_utc_sec="$(date --utc -d "${stats_last_changed_date_utc}Z" +%s)"

    if (( current_date_utc_sec > last_changed_date_utc_sec )); then
      (( last_changed_date_offset_day = (current_date_utc_sec - last_changed_date_utc_sec) / 60 / 60 / 24 ))
      last_changed_date_offset="-$(printf %02u "$last_changed_date_offset_day")T"
    else
      (( last_changed_date_offset_day = (last_changed_date_utc_sec - current_date_utc_sec) / 60 / 60 / 24 ))
      last_changed_date_offset="+$(printf %02u "$last_changed_date_offset_day")T"
    fi
  fi
fi

gh_print_notice_and_write_to_changelog_text_bullet_ln "removed / changed dates: [${stats_removed_dates[*]}] / [${stats_changed_dates[*]}]"

if (( count_outdated_prev == count_outdated_next && uniques_outdated_prev == uniques_outdated_next && \
      count_prev == count_next && uniques_prev == uniques_next )) && [[ \
      "$stats_timestamp_next_seq" == "$stats_timestamp_prev_seq" && \
      "$stats_count_next_seq" == "$stats_count_prev_seq" && \
      "$stats_uniques_next_seq" == "$stats_uniques_prev_seq" ]]; then
  gh_enable_print_buffering

  gh_print_warning_and_write_to_changelog_text_bullet_ln "$0: warning: nothing is changed, no new statistic." "nothing is changed, no new statistic"

  (( ! CONTINUE_ON_EMPTY_CHANGES )) && exit 255
fi

{
  echo -n "\
{
  \"timestamp\" : \"$current_date_time_utc\",
  \"count_outdated\" : $count_outdated_next,
  \"uniques_outdated\" : $uniques_outdated_next,
  \"count\" : $count_next,
  \"uniques\" : $uniques_next,
  \"$stat_list_key\" : ["

  for (( i=0; i < ${#stats_timestamps[@]}; i++ )); do
    (( i )) && echo -n ','
    echo ''

    echo -n "\
    {
      \"timestamp\": \"${stats_timestamps[i]}\",
      \"count\": ${stats_counts[i]},
      \"count_minmax\": [ ${stats_count_min[i]}, ${stats_count_max[i]} ],
      \"count_decinc\": [ ${stats_count_dec[i]}, ${stats_count_inc[i]} ],
      \"uniques\": ${stats_uniques[i]},
      \"uniques_minmax\": [ ${stats_uniques_min[i]}, ${stats_uniques_max[i]} ],
      \"uniques_decinc\": [ ${stats_uniques_dec[i]}, ${stats_uniques_inc[i]} ]
    }"
  done

  (( i )) && echo -e -n "\n  "

  echo ']
}'
} > $stats_accum_json

# CAUTION:
#   The GitHub has an issue with the `latest.json` file residual (no effect) changes related to the statistic interpolation issue,
#   when the first record (or set of records from beginning) related to not current day does change (decrease) or remove but nothing else does change.
#   That triggers a consequences like a repository commit with residual changes after script exit. To avoid that we must detect residual changes in the
#   `latest.json` file and return non zero return code with a warning.
#
has_not_residual_changes=0
has_residual_changes=0

for i in $(jq ".$stat_list_key|keys|.[]" $stats_json); do
  # CAUTION:
  #   Prevent of invalid values spread if upstream user didn't properly commit completely correct json file or didn't commit at all.
  #
  jq_is_null i && break

  IFS=$'\n' read -r -d '' timestamp count uniques <<< "$(jq -c -r ".$stat_list_key[$i].timestamp,.$stat_list_key[$i].count,.$stat_list_key[$i].uniques" $stats_json)"

  # CAUTION:
  #   Prevent of invalid values spread if upstream user didn't properly commit completely correct json file or didn't commit at all.
  #
  jq_fix_null \
    count:0 \
    uniques:0

  timestamp_date_utc="${timestamp/%T*}"

  # changes at current day is always not residual
  if [[ "$timestamp_date_utc" == "$current_date_utc" ]]; then
    has_not_residual_changes=1
    break
  fi

  timestamp_year_utc="${timestamp_date_utc/%-*}"

  timestamp_year_dir="$stats_by_year_dir/$timestamp_year_utc"
  year_date_json="$timestamp_year_dir/$timestamp_date_utc.json"

  if [[ -f "$year_date_json" ]]; then
    IFS=$'\n' read -r -d '' count_saved uniques_saved count_min_saved count_max_saved uniques_min_saved uniques_max_saved <<< \
      "$(jq -c -r ".count,.uniques,.count_minmax[0],.count_minmax[1],.uniques_minmax[0],.uniques_minmax[1]" $year_date_json)"

    # CAUTION:
    #   Prevent of invalid values spread if upstream user didn't properly commit completely correct json file or didn't commit at all.
    #
    jq_fix_null \
      count_saved:0 \
      uniques_saved:0 \
      count_min_saved:$count_saved \
      count_max_saved:$count_saved \
      uniques_min_saved:$uniques_saved \
      uniques_max_saved:$uniques_saved
  else
    has_not_residual_changes=1
    break
  fi

  if (( count > count_saved || uniques > uniques_saved )); then
    has_not_residual_changes=1
    break
  elif (( count < count_saved || uniques < uniques_saved )); then
    has_residual_changes=1
  fi
done

# treat equality as not residual change
if (( has_residual_changes && ! has_not_residual_changes )); then
  gh_enable_print_buffering

  gh_print_warning_and_write_to_changelog_text_bullet_ln "$0: warning: json data has only residual changes which has no effect and ignored." "json data has only residual changes which has no effect and ignored"

  (( ! CONTINUE_ON_RESIDUAL_CHANGES )) && exit 255
fi

commit_message_date_time_prefix="$current_date_utc"

if (( ENABLE_COMMIT_MESSAGE_DATE_WITH_TIME )); then
  commit_message_date_time_prefix="${current_date_time_utc%:*Z}Z"
fi

if (( ENABLE_COMMIT_MESSAGE_DATE_TIME_WITH_LAST_CHANGED_DATE_OFFSET )); then
  commit_message_date_time_prefix="${commit_message_date_time_prefix}$last_changed_date_offset"
fi

# return output variables

# CAUTION:
#   We must explicitly state the statistic calculation time in the script, because
#   the time taken from the input and the time set to commit changes ARE DIFFERENT
#   and may be shifted to the next day.
#
gh_set_env_var STATS_DATE_UTC                     "$current_date_utc"
gh_set_env_var STATS_DATE_TIME_UTC                "$current_date_time_utc"

# counters of last changed date
gh_set_env_var STATS_LAST_CHANGED_DATE_COUNT      "$stats_last_changed_date_count"
gh_set_env_var STATS_LAST_CHANGED_DATE_UNIQUES    "$stats_last_changed_date_uniques"

gh_set_env_var STATS_LAST_CHANGED_DATE_COUNT_INC    "$stats_last_changed_date_count_inc"
gh_set_env_var STATS_LAST_CHANGED_DATE_UNIQUES_INC  "$stats_last_changed_date_uniques_inc"
gh_set_env_var STATS_LAST_CHANGED_DATE_COUNT_DEC    "$stats_last_changed_date_count_dec"
gh_set_env_var STATS_LAST_CHANGED_DATE_UNIQUES_DEC  "$stats_last_changed_date_uniques_dec"

gh_set_env_var STATS_REMOVED_DATES                "${stats_removed_dates[*]}"
gh_set_env_var STATS_CHANGED_DATES                "${stats_changed_dates[*]}"

# counters of GitHub dated period (not greater than 14-days)
gh_set_env_var STATS_DATED_COUNT                  "$count_next"
gh_set_env_var STATS_DATED_UNIQUES                "$uniques_next"

# counters of outdated records (greater than 14 days)
gh_set_env_var STATS_OUTDATED_COUNT               "$count_outdated_next"
gh_set_env_var STATS_OUTDATED_UNIQUES             "$uniques_outdated_next"

gh_set_env_var STATS_PREV_EXEC_COUNT_INC          "$stats_prev_exec_count_inc"
gh_set_env_var STATS_PREV_EXEC_UNIQUES_INC        "$stats_prev_exec_uniques_inc"
gh_set_env_var STATS_PREV_EXEC_COUNT_DEC          "$stats_prev_exec_count_dec"
gh_set_env_var STATS_PREV_EXEC_UNIQUES_DEC        "$stats_prev_exec_uniques_dec"

gh_set_env_var COMMIT_MESSAGE_DATE_TIME_PREFIX    "$commit_message_date_time_prefix"

gh_set_env_var COMMIT_MESSAGE_PREFIX              "unq all: +$stats_last_changed_date_uniques_inc +$stats_last_changed_date_count_inc -$stats_last_changed_date_uniques_dec -$stats_last_changed_date_count_dec / $stats_last_changed_date_uniques $stats_last_changed_date_count"
gh_set_env_var COMMIT_MESSAGE_SUFFIX              "$commit_msg_entity"

tkl_set_return
