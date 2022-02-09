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
  print_error "$0: error: \`stats_dir\` variable must be defined."
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

[[ -z "$stats_list_key" ]] && {
  print_error "$0: error: \`stats_list_key\` variable must be defined."
  exit 255
}

[[ -z "$stats_by_year_dir" ]] && stats_by_year_dir="$stats_dir/by_year"
[[ -z "$stats_json" ]] && stats_json="$stats_dir/latest.json"
[[ -z "$stats_accum_json" ]] && stats_accum_json="$stats_dir/latest-accum.json"

current_date_time_utc=$(date --utc +%FT%TZ)

print_notice "current date/time: $current_date_time_utc"

current_date_utc=${current_date_time_utc/%T*}

IFS=$'\n' read -r -d '' count_outdated_prev uniques_outdated_prev count_prev uniques_prev <<< "$(jq -c -r ".count_outdated,.uniques_outdated,.count,.uniques" $stats_accum_json)"

# CAUTION:
#   Prevent of invalid values spread if upstream user didn't properly commit completely correct json file or didn't commit at all.
#
[[ -z "$count_outdated_prev" || "$count_outdated_prev" == 'null' ]] && count_outdated_prev=0
[[ -z "$uniques_outdated_prev" || "$uniques_outdated_prev" == 'null' ]] && uniques_outdated_prev=0
[[ -z "$count_prev" || "$count_prev" == 'null' ]] && count_prev=0
[[ -z "$uniques_prev" || "$uniques_prev" == 'null' ]] && uniques_prev=0

print_notice "prev accum: outdated-all outdated-unq / all unq: $count_outdated_prev $uniques_outdated_prev / $count_prev $uniques_prev"

# CAUTION:
#   Sometimes the json data file comes empty for some reason.
#   We must check that special case to avoid invalid accumulation!
#
IFS=$'\n' read -r -d '' count uniques stats_length <<< $(jq ".count,.uniques,.$stats_list_key|length" $stats_json)

# CAUTION:
#   Prevent of invalid values spread if upstream user didn't properly commit completely correct json file or didn't commit at all.
#
[[ -z "$count" || "$count" == 'null' ]] && count=0
[[ -z "$uniques" || "$uniques" == 'null' ]] && uniques=0
[[ -z "$stats_length" || "$stats_length" == 'null' ]] && stats_length=0

print_notice "last 14d: all unq: $count $uniques"

(( !count && !uniques && !stats_length )) && {
  print_error "$0: error: json data is invalid or empty."

  # try to request json generic response fields to print them as a notice
  IFS=$'\n' read -r -d '' json_message json_url json_documentation_url <<< $(jq ".message,.url,.documentation_url" $stats_json)

  [[ "$json_message" == 'null' ]] && json_message=''
  [[ "$json_url" == 'null' ]] && json_url=''
  [[ "$json_documentation_url" == 'null' ]] && json_documentation_url=''

  [[ -n "$json_message" ]] && print_notice "json generic response: message: \`$json_message\`"
  [[ -n "$json_url" ]] && print_notice "json generic response: url: \`$json_url\`"
  [[ -n "$json_documentation_url" ]] && print_notice "json generic response: documentation_url: \`$json_documentation_url\`"

  exit 255
}

# CAUTION:
#   The GitHub has an issue with the `latest.json` file residual (no effect) changes related to the statistic interpolation issue,
#   when the first record (or set of records from beginning) related to not current day does change (decrease) or remove but nothing else does change.
#   That triggers a consequences like a repository commit with residual changes after script exit. To avoid that we must detect residual changes in the
#   `latest.json` file and return non zero return code with a warning.
#
has_not_residual_changes=0
has_residual_changes=0

for i in $(jq ".$stats_list_key|keys|.[]" $stats_json); do
  # CAUTION:
  #   Prevent of invalid values spread if upstream user didn't properly commit completely correct json file or didn't commit at all.
  #
  [[ -z "$i" || "$i" == 'null' ]] && break

  IFS=$'\n' read -r -d '' timestamp count uniques <<< "$(jq -c -r ".$stats_list_key[$i].timestamp,.$stats_list_key[$i].count,.$stats_list_key[$i].uniques" $stats_json)"

  # CAUTION:
  #   Prevent of invalid values spread if upstream user didn't properly commit completely correct json file or didn't commit at all.
  #
  [[ -z "$count" || "$count" == 'null' ]] && count=0
  [[ -z "$uniques" || "$uniques" == 'null' ]] && uniques=0

  timestamp_date_utc=${timestamp/%T*}

  # changes at current day is always not residual
  if [[ "$timestamp_date_utc" == "$current_date_utc" ]]; then
    has_not_residual_changes=1
    break
  fi

  timestamp_year_utc=${timestamp_date_utc/%-*}

  timestamp_year_dir="$stats_by_year_dir/$timestamp_year_utc"
  year_date_json="$timestamp_year_dir/$timestamp_date_utc.json"

  if [[ -f "$year_date_json" ]]; then
    IFS=$'\n' read -r -d '' count_saved uniques_saved count_min_saved count_max_saved uniques_min_saved uniques_max_saved <<< \
      "$(jq -c -r ".count,.uniques,.count_minmax[0],.count_minmax[1],.uniques_minmax[0],.uniques_minmax[1]" $year_date_json)"

    # CAUTION:
    #   Prevent of invalid values spread if upstream user didn't properly commit completely correct json file or didn't commit at all.
    #
    [[ -z "$count_saved" || "$count_saved" == 'null' ]] && count_saved=0
    [[ -z "$uniques_saved" || "$uniques_saved" == 'null' ]] && uniques_saved=0
    [[ -z "$count_min_saved" || "$count_min_saved" == 'null' ]] && count_min_saved=$count_saved
    [[ -z "$count_max_saved" || "$count_max_saved" == 'null' ]] && count_max_saved=$count_saved
    [[ -z "$uniques_min_saved" || "$uniques_min_saved" == 'null' ]] && uniques_min_saved=$uniques_saved
    [[ -z "$uniques_max_saved" || "$uniques_max_saved" == 'null' ]] && uniques_max_saved=$uniques_saved
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
  print_warning "$0: warning: json data has only residual changes which has no effect and ignored."
  exit 255
fi

stats_accum_timestamp=()
stats_accum_count=()
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

for i in $(jq ".$stats_list_key|keys|.[]" $stats_accum_json); do
  # CAUTION:
  #   Prevent of invalid values spread if upstream user didn't properly commit completely correct json file or didn't commit at all.
  #
  [[ -z "$i" || "$i" == 'null' ]] && break

  IFS=$'\n' read -r -d '' timestamp count uniques count_max uniques_max <<< \
    "$(jq -c -r ".$stats_list_key[$i].timestamp,.$stats_list_key[$i].count,.$stats_list_key[$i].uniques,
        .$stats_list_key[$i].count_minmax[1],.$stats_list_key[$i].uniques_minmax[1]" $stats_accum_json)"

  # CAUTION:
  #   Prevent of invalid values spread if upstream user didn't properly commit completely correct json file or didn't commit at all.
  #
  [[ -z "$count" || "$count" == 'null' ]] && count=0
  [[ -z "$uniques" || "$uniques" == 'null' ]] && uniques=0

  stats_accum_timestamp[${#stats_accum_timestamp[@]}]="$timestamp"
  stats_accum_count[${#stats_accum_count[@]}]=$count
  stats_accum_uniques[${#stats_accum_uniques[@]}]=$uniques

  [[ -z "$count_max" || "$count_max" == 'null' ]] && count_max=$count
  [[ -z "$uniques_max" || "$uniques_max" == 'null' ]] && uniques_max=$uniques

  stats_accum_count_max[${#stats_accum_count_max[@]}]=$count_max
  stats_accum_uniques_max[${#stats_accum_uniques_max[@]}]=$uniques_max

  stats_timestamp_prev_seq="$stats_timestamp_prev_seq|$timestamp"
  stats_count_prev_seq="$stats_count_prev_seq|$count"
  stats_uniques_prev_seq="$stats_uniques_prev_seq|$uniques"
done

# stats between previos/next script execution (dependent to the pipeline scheduler times)
stats_prev_exec_count_inc=0
stats_prev_exec_uniques_inc=0
stats_prev_exec_count_dec=0
stats_prev_exec_uniques_dec=0

first_stats_timestamp=""

stats_timestamp=()
stats_count=()
stats_uniques=()

stats_timestamp_next_seq=""
stats_count_next_seq=""
stats_unique_next_seq=""

stats_count_min=()
stats_count_max=()
stats_uniques_min=()
stats_uniques_max=()

for i in $(jq ".$stats_list_key|keys|.[]" $stats_json); do
  # CAUTION:
  #   Prevent of invalid values spread if upstream user didn't properly commit completely correct json file or didn't commit at all.
  #
  [[ -z "$i" || "$i" == 'null' ]] && break

  IFS=$'\n' read -r -d '' timestamp count uniques <<< "$(jq -c -r ".$stats_list_key[$i].timestamp,.$stats_list_key[$i].count,.$stats_list_key[$i].uniques" $stats_json)"

  # CAUTION:
  #   Prevent of invalid values spread if upstream user didn't properly commit completely correct json file or didn't commit at all.
  #
  [[ -z "$count" || "$count" == 'null' ]] && count=0
  [[ -z "$uniques" || "$uniques" == 'null' ]] && uniques=0

  (( ! i )) && first_stats_timestamp="$timestamp"

  stats_timestamp[${#stats_timestamp[@]}]="$timestamp"
  stats_count[${#stats_count[@]}]=$count
  stats_uniques[${#stats_uniques[@]}]=$uniques

  stats_timestamp_next_seq="$stats_timestamp_next_seq|$timestamp"
  stats_count_next_seq="$stats_count_next_seq|$count"
  stats_uniques_next_seq="$stats_uniques_next_seq|$uniques"

  timestamp_date_utc=${timestamp/%T*}
  timestamp_year_utc=${timestamp_date_utc/%-*}

  timestamp_year_dir="$stats_by_year_dir/$timestamp_year_utc"
  year_date_json="$timestamp_year_dir/$timestamp_date_utc.json"

  [[ ! -d "$timestamp_year_dir" ]] && mkdir -p "$timestamp_year_dir"

  count_min=$count
  count_max=$count
  uniques_min=$uniques
  uniques_max=$uniques

  count_inc=0
  count_dec=0
  uniques_inc=0
  uniques_dec=0

  count_saved=0
  uniques_saved=0
  count_prev_day_inc_saved=0
  count_prev_day_dec_saved=0
  uniques_prev_day_inc_saved=0
  uniques_prev_day_dec_saved=0
  count_min_saved=0
  count_max_saved=0
  uniques_min_saved=0
  uniques_max_saved=0

  # calculate min/max
  if [[ -f "$year_date_json" ]]; then
    IFS=$'\n' read -r -d '' count_saved uniques_saved count_prev_day_inc_saved count_prev_day_dec_saved uniques_prev_day_inc_saved uniques_prev_day_dec_saved count_min_saved count_max_saved uniques_min_saved uniques_max_saved <<< \
      "$(jq -c -r ".count,.uniques,.count_prev_day_inc,.count_prev_day_dec,.uniques_prev_day_inc,.uniques_prev_day_dec,.count_minmax[0],.count_minmax[1],.uniques_minmax[0],.uniques_minmax[1]" $year_date_json)"

    # CAUTION:
    #   Prevent of invalid values spread if upstream user didn't properly commit completely correct json file or didn't commit at all.
    #
    [[ -z "$count_saved" || "$count_saved" == 'null' ]] && count_saved=0
    [[ -z "$uniques_saved" || "$uniques_saved" == 'null' ]] && uniques_saved=0
    [[ -z "$count_prev_day_inc_saved" || "$count_prev_day_inc_saved" == 'null' ]] && count_prev_day_inc_saved=0
    [[ -z "$count_prev_day_dec_saved" || "$count_prev_day_dec_saved" == 'null' ]] && count_prev_day_dec_saved=0
    [[ -z "$uniques_prev_day_inc_saved" || "$uniques_prev_day_inc_saved" == 'null' ]] && uniques_prev_day_inc_saved=0
    [[ -z "$uniques_prev_day_dec_saved" || "$uniques_prev_day_dec_saved" == 'null' ]] && uniques_prev_day_dec_saved=0
    [[ -z "$count_min_saved" || "$count_min_saved" == 'null' ]] && count_min_saved=$count_saved
    [[ -z "$count_max_saved" || "$count_max_saved" == 'null' ]] && count_max_saved=$count_saved
    [[ -z "$uniques_min_saved" || "$uniques_min_saved" == 'null' ]] && uniques_min_saved=$uniques_saved
    [[ -z "$uniques_max_saved" || "$uniques_max_saved" == 'null' ]] && uniques_max_saved=$uniques_saved

    (( count_max_saved > count_max )) && count_max=$count_max_saved
    (( count_min_saved < count_min )) && count_min=$count_min_saved
    (( uniques_max_saved > uniques_max )) && uniques_max=$uniques_max_saved
    (( uniques_min_saved < uniques_min )) && uniques_min=$uniques_min_saved
  fi

  stats_count_min[${#stats_count_min[@]}]=$count_min
  stats_count_max[${#stats_count_max[@]}]=$count_max
  stats_uniques_min[${#stats_uniques_min[@]}]=$uniques_min
  stats_uniques_max[${#stats_uniques_max[@]}]=$uniques_max

  (( count > count_saved )) && (( count_inc=count-count_saved ))
  (( uniques > uniques_saved )) && (( uniques_inc=uniques-uniques_saved ))

  (( count < count_saved )) && (( count_dec=count_saved-count ))
  (( uniques < uniques_saved )) && (( uniques_dec=uniques_saved-uniques ))

  (( stats_prev_exec_count_inc+=count_inc ))
  (( stats_prev_exec_uniques_inc+=uniques_inc ))

  (( stats_prev_exec_count_dec+=count_dec ))
  (( stats_prev_exec_uniques_dec+=uniques_dec ))

  if (( count != count_saved || uniques != uniques_saved || \
        count_min != count_min_saved || count_max != count_max_saved || \
        uniques_min != uniques_min_saved || uniques_max != uniques_max_saved )); then
  echo "\
{
  \"timestamp\" : \"$current_date_time_utc\",
  \"count\" : $count,
  \"count_minmax\" : [ $count_min, $count_max ],
  \"count_prev_day_inc\" : $count_prev_day_inc_saved,
  \"count_prev_day_dec\" : $count_prev_day_dec_saved,
  \"uniques\" : $uniques,
  \"uniques_minmax\" : [ $uniques_min, $uniques_max ],
  \"uniques_prev_day_inc\" : $uniques_prev_day_inc_saved,
  \"uniques_prev_day_dec\" : $uniques_prev_day_dec_saved
}" > "$year_date_json"
  fi
done

# stats between last change in previous/next day (independent to the pipeline scheduler times)
stats_prev_day_count_inc=0
stats_prev_day_uniques_inc=0
stats_prev_day_count_dec=0
stats_prev_day_uniques_dec=0

count_saved=0
uniques_saved=0
count_prev_day_inc_saved=0
count_prev_day_dec_saved=0
uniques_prev_day_inc_saved=0
uniques_prev_day_dec_saved=0
count_min_saved=0
count_max_saved=0
uniques_min_saved=0
uniques_max_saved=0

timestamp_date_utc=$current_date_utc
timestamp_year_utc=${current_date_utc/%-*}
timestamp_year_dir="$stats_by_year_dir/$timestamp_year_utc"
year_date_json="$timestamp_year_dir/$timestamp_date_utc.json"

if [[ -f "$year_date_json" ]]; then
  IFS=$'\n' read -r -d '' count_saved uniques_saved count_prev_day_inc_saved count_prev_day_dec_saved uniques_prev_day_inc_saved uniques_prev_day_dec_saved count_min_saved count_max_saved uniques_min_saved uniques_max_saved <<< \
    "$(jq -c -r ".count,.uniques,.count_prev_day_inc,.count_prev_day_dec,.uniques_prev_day_inc,.uniques_prev_day_dec,.count_minmax[0],.count_minmax[1],.uniques_minmax[0],.uniques_minmax[1]" $year_date_json)"

  # CAUTION:
  #   Prevent of invalid values spread if upstream user didn't properly commit completely correct json file or didn't commit at all.
  #
  [[ -z "$count_saved" || "$count_saved" == 'null' ]] && count_saved=0
  [[ -z "$uniques_saved" || "$uniques_saved" == 'null' ]] && uniques_saved=0
  [[ -z "$count_prev_day_inc_saved" || "$count_prev_day_inc_saved" == 'null' ]] && count_prev_day_inc_saved=0
  [[ -z "$count_prev_day_dec_saved" || "$count_prev_day_dec_saved" == 'null' ]] && count_prev_day_dec_saved=0
  [[ -z "$uniques_prev_day_inc_saved" || "$uniques_prev_day_inc_saved" == 'null' ]] && uniques_prev_day_inc_saved=0
  [[ -z "$uniques_prev_day_dec_saved" || "$uniques_prev_day_dec_saved" == 'null' ]] && uniques_prev_day_dec_saved=0
  [[ -z "$count_min_saved" || "$count_min_saved" == 'null' ]] && count_min_saved=$count_saved
  [[ -z "$count_max_saved" || "$count_max_saved" == 'null' ]] && count_max_saved=$count_saved
  [[ -z "$uniques_min_saved" || "$uniques_min_saved" == 'null' ]] && uniques_min_saved=$uniques_saved
  [[ -z "$uniques_max_saved" || "$uniques_max_saved" == 'null' ]] && uniques_max_saved=$uniques_saved
fi

(( stats_prev_day_count_inc+=count_prev_day_inc_saved+stats_prev_exec_count_inc ))
(( stats_prev_day_uniques_inc+=uniques_prev_day_inc_saved+stats_prev_exec_uniques_inc ))

(( stats_prev_day_count_dec+=count_prev_day_dec_saved+stats_prev_exec_count_dec ))
(( stats_prev_day_uniques_dec+=uniques_prev_day_dec_saved+stats_prev_exec_uniques_dec ))

# CAUTION:
#   The changes over the current day can unexist, but nonetheless they can exist for all previous days
#   because upstream may update any of previous day at the current day, so we must detect changes irrespective
#   to previously saved values.
#
if (( stats_prev_exec_count_inc || stats_prev_exec_uniques_inc || stats_prev_exec_count_dec || stats_prev_exec_uniques_dec )); then
  [[ ! -d "$timestamp_year_dir" ]] && mkdir -p "$timestamp_year_dir"

  echo "\
{
  \"timestamp\" : \"$current_date_time_utc\",
  \"count\" : $count_saved,
  \"count_minmax\" : [ $count_min_saved, $count_max_saved ],
  \"count_prev_day_inc\" : $stats_prev_day_count_inc,
  \"count_prev_day_dec\" : $stats_prev_day_count_dec,
  \"uniques\" : $uniques_saved,
  \"uniques_minmax\" : [ $uniques_min_saved, $uniques_max_saved ],
  \"uniques_prev_day_inc\" : $stats_prev_day_uniques_inc,
  \"uniques_prev_day_dec\" : $stats_prev_day_uniques_dec
}" > "$year_date_json"
fi

# accumulate statistic
count_outdated_next=$count_outdated_prev
uniques_outdated_next=$uniques_outdated_prev

j=0
for (( i=0; i < ${#stats_accum_timestamp[@]}; i++)); do
  if [[ -z "$first_stats_timestamp" || "${stats_accum_timestamp[i]}" < "$first_stats_timestamp" ]]; then
    if (( j )); then
      (( count_outdated_next += ${stats_accum_count[i]} ))
      (( uniques_outdated_next += ${stats_accum_uniques[i]} ))
    else
      (( count_outdated_next += ${stats_accum_count_max[i]} ))
      (( uniques_outdated_next += ${stats_accum_uniques_max[i]} ))
    fi
    (( j++ ))
  fi
done

count_next=0
uniques_next=0

for (( i=0; i < ${#stats_timestamp[@]}; i++)); do
  (( count_next += ${stats_count[i]} ))
  (( uniques_next += ${stats_uniques[i]} ))
done

(( count_next += count_outdated_next ))
(( uniques_next += uniques_outdated_next ))

print_notice "next accum: outdated-all outdated-unq / all unq: $count_outdated_next $uniques_outdated_next / $count_next $uniques_next"

print_notice "prev json diff: unq all: +$stats_prev_exec_uniques_inc +$stats_prev_exec_count_inc / -$stats_prev_exec_uniques_dec -$stats_prev_exec_count_dec"

print_notice "prev day diff: unq all: +$stats_prev_day_uniques_inc +$stats_prev_day_count_inc / -$stats_prev_day_uniques_dec -$stats_prev_day_count_dec"

if (( count_outdated_prev == count_outdated_next && uniques_outdated_prev == uniques_outdated_next && \
      count_prev == count_next && uniques_prev == uniques_next )) && [[ \
      "$stats_timestamp_next_seq" == "$stats_timestamp_prev_seq" && \
      "$stats_count_next_seq" == "$stats_count_prev_seq" && \
      "$stats_uniques_next_seq" == "$stats_uniques_prev_seq" ]]; then
  print_warning "$0: warning: nothing is changed, no new statistic."
  exit 255
fi

{
  echo -n "\
{
  \"timestamp\" : \"$current_date_time_utc\",
  \"count_outdated\" : $count_outdated_next,
  \"uniques_outdated\" : $uniques_outdated_next,
  \"count\" : $count_next,
  \"uniques\" : $uniques_next,
  \"$stats_list_key\" : ["

  for (( i=0; i < ${#stats_timestamp[@]}; i++)); do
    (( i )) && echo -n ','
    echo ''

    echo -n "\
    {
      \"timestamp\": \"${stats_timestamp[i]}\",
      \"count\": ${stats_count[i]},
      \"count_minmax\": [ ${stats_count_min[i]}, ${stats_count_max[i]} ],
      \"uniques\": ${stats_uniques[i]},
      \"uniques_minmax\": [ ${stats_uniques_min[i]}, ${stats_uniques_max[i]} ]
    }"
  done

  (( i )) && echo -e -n "\n  "

  echo ']
}'
} > $stats_accum_json || exit $?

# return output variables

# CAUTION:
#   We must explicitly state the statistic calculation time in the script, because
#   the time taken from a script and the time set to commit changes ARE DIFFERENT
#   and may be shifted to the next day.
#
set_env_var STATS_DATE_UTC                "$current_date_utc"
set_env_var STATS_DATE_TIME_UTC           "$current_date_time_utc"

set_env_var STATS_PREV_EXEC_COUNT_INC     "$stats_prev_exec_count_inc"
set_env_var STATS_PREV_EXEC_UNIQUES_INC   "$stats_prev_exec_uniques_inc"
set_env_var STATS_PREV_EXEC_COUNT_DEC     "$stats_prev_exec_count_dec"
set_env_var STATS_PREV_EXEC_UNIQUES_DEC   "$stats_prev_exec_uniques_dec"

set_env_var STATS_PREV_DAY_COUNT_INC      "$stats_prev_day_count_inc"
set_env_var STATS_PREV_DAY_UNIQUES_INC    "$stats_prev_day_uniques_inc"
set_env_var STATS_PREV_DAY_COUNT_DEC      "$stats_prev_day_count_dec"
set_env_var STATS_PREV_DAY_UNIQUES_DEC    "$stats_prev_day_uniques_dec"

set_env_var COMMIT_MESSAGE_SUFFIX         " | unq all: +$stats_prev_day_uniques_inc +$stats_prev_day_count_inc / -$stats_prev_day_uniques_dec -$stats_prev_day_count_dec"
