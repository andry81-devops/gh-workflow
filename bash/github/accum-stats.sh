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

function set_env_var()
{
  [[ -n "$GITHUB_ACTIONS" ]] && echo "$1=$2" >> $GITHUB_ENV
}

[[ -z "$stats_dir" ]] && {
  print_error "$0: error: \`stats_dir\` variable must be defined."
  exit 255
} >&2

[[ -z "$stats_list_key" ]] && {
  print_error "$0: error: \`stats_list_key\` variable must be defined."
  exit 255
} >&2

[[ -z "$stats_by_year_dir" ]] && stats_by_year_dir="$stats_dir/by_year"
[[ -z "$stats_json" ]] && stats_json="$stats_dir/latest.json"
[[ -z "$stats_accum_json" ]] && stats_accum_json="$stats_dir/latest-accum.json"

current_date_time_utc=$(date --utc +%FT%TZ)

current_date_time_utc=${current_date_time_utc//:/-}
current_date_utc=${current_date_time_utc/%T*}

# CAUTION:
#   Sometimes the json data file comes empty for some reason.
#   We must check that special case to avoid invalid accumulation!
#
IFS=$'\n' read -r -d '' count uniques stats_length <<< $(jq ".count,.uniques,.$stats_list_key|length" $stats_json)

(( ! count && ! uniques && ! stats_length )) && {
  print_error "$0: error: json data is invalid or empty."
  exit 255
} >&2

# CAUTION:
#   The GitHub has an issue with the `latest.json` file residual (no effect) changes related to the statistic interpolation issue,
#   when the first record (or set of records from beginning) related to not current day does change (decrease) or remove but nothing else does change.
#   That triggers a consequences like a repository commit with residual changes after script exit. To avoid that we must detect residual changes in the
#   `latest.json` file and return non zero return code with a warning.
#
has_not_residual_changes=0
has_residual_changes=0

for i in $(jq ".$stats_list_key|keys|.[]" $stats_json); do
  IFS=$'\n' read -r -d '' timestamp count uniques <<< "$(jq -c -r ".$stats_list_key[$i].timestamp,.$stats_list_key[$i].count,.$stats_list_key[$i].uniques" $stats_json)"

  timestamp_date_time_utc=${timestamp//:/-}
  timestamp_date_utc=${timestamp_date_time_utc/%T*}

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

IFS=$'\n' read -r -d '' count_outdated_prev uniques_outdated_prev count_prev uniques_prev <<< "$(jq -c -r ".count_outdated,.uniques_outdated,.count,.uniques" $stats_accum_json)"

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
  IFS=$'\n' read -r -d '' timestamp count uniques count_max uniques_max <<< \
    "$(jq -c -r ".$stats_list_key[$i].timestamp,.$stats_list_key[$i].count,.$stats_list_key[$i].uniques,
        .$stats_list_key[$i].count_minmax[1],.$stats_list_key[$i].uniques_minmax[1]" $stats_accum_json)"

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

# stats per script execution (output)
stats_count_inc=0
stats_uniques_inc=0
stats_count_dec=0
stats_uniques_dec=0

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
  IFS=$'\n' read -r -d '' timestamp count uniques <<< "$(jq -c -r ".$stats_list_key[$i].timestamp,.$stats_list_key[$i].count,.$stats_list_key[$i].uniques" $stats_json)"

  (( ! i )) && first_stats_timestamp="$timestamp"

  stats_timestamp[${#stats_timestamp[@]}]="$timestamp"
  stats_count[${#stats_count[@]}]=$count
  stats_uniques[${#stats_uniques[@]}]=$uniques

  stats_timestamp_next_seq="$stats_timestamp_next_seq|$timestamp"
  stats_count_next_seq="$stats_count_next_seq|$count"
  stats_uniques_next_seq="$stats_uniques_next_seq|$uniques"

  timestamp_date_time_utc=${timestamp//:/-}
  timestamp_date_utc=${timestamp_date_time_utc/%T*}
  timestamp_year_utc=${timestamp_date_utc/%-*}

  timestamp_year_dir="$stats_by_year_dir/$timestamp_year_utc"
  year_date_json="$timestamp_year_dir/$timestamp_date_utc.json"

  [[ ! -d "$timestamp_year_dir" ]] && mkdir -p "$timestamp_year_dir"

  count_min=$count
  count_max=$count
  uniques_min=$uniques
  uniques_max=$uniques

  count_saved=0
  uniques_saved=0
  count_min_saved=0
  count_max_saved=0
  uniques_min_saved=0
  uniques_max_saved=0

  # calculate min/max
  if [[ -f "$year_date_json" ]]; then
    IFS=$'\n' read -r -d '' count_saved uniques_saved count_min_saved count_max_saved uniques_min_saved uniques_max_saved <<< \
      "$(jq -c -r ".count,.uniques,.count_minmax[0],.count_minmax[1],.uniques_minmax[0],.uniques_minmax[1]" $year_date_json)"

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

  (( count > count_saved )) && (( stats_count_inc+=count-count_saved ))
  (( uniques > uniques_saved )) && (( stats_uniques_inc+=uniques-uniques_saved ))

  (( count < count_saved )) && (( stats_count_dec+=count_saved-count ))
  (( uniques < uniques_saved )) && (( stats_uniques_dec+=uniques_saved-uniques ))

  if (( count != count_saved || uniques != uniques_saved || count_min != count_min_saved || count_max != count_max_saved || \
        uniques_min != uniques_min_saved || uniques_max != uniques_max_saved )); then
  echo "\
{
  \"timestamp\" : \"$timestamp\",
  \"count\" : $count,
  \"count_minmax\" : [ $count_min, $count_max ],
  \"uniques\" : $uniques,
  \"uniques_minmax\" : [ $uniques_min, $uniques_max ]
}" > "$year_date_json"
  fi
done

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

(( count_outdated_prev == count_outdated_next && uniques_outdated_prev == uniques_outdated_next && \
   count_prev == count_next && uniques_prev == uniques_next )) && [[ \
   "$stats_timestamp_next_seq" == "$stats_timestamp_prev_seq" && \
   "$stats_count_next_seq" == "$stats_count_prev_seq" && \
   "$stats_uniques_next_seq" == "$stats_uniques_prev_seq" ]] && {
  print_warning "$0: warning: nothing is changed, no new statistic."
  exit 255
} >&2

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
set_env_var STATS_COUNT_INC   "$stats_count_inc"
set_env_var STATS_UNIQUES_INC "$stats_uniques_inc"
set_env_var STATS_COUNT_DEC   "$stats_count_dec"
set_env_var STATS_UNIQUES_DEC "$stats_uniques_dec"
