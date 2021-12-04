#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

function print_error()
{
  [[ -n "$GITHUB_ACTIONS" ]] && echo "::error ::$*"
  echo "$*" >&2
}

function print_warning()
{
  [[ -n "$GITHUB_ACTIONS" ]] && echo "::warning ::$*"
  echo "$*" >&2
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

stats_accum_timestamp=()
stats_accum_count=()
stats_accum_uniques=()

IFS=$'\n' read -r -d '' count_outdated_prev uniques_outdated_prev count_prev uniques_prev <<< "$(jq -c -r ".count_outdated,.uniques_outdated,.count,.uniques" $stats_accum_json)"

stats_timestamp_prev_seq=""
stats_count_prev_seq=""
stats_unique_prev_seq=""

# CAUTION:
#   Statistic can has values interpolation from, for example, per hour basis to day basis, which means the edge values can fluctuate to lower levels.
#   To prevent save up lower levels of outdated values we must to calculate the range of fluctuation for all values and save maximal values instead of
#   interpolated values for edge values.
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

# CAUTION:
#   Sometimes the json data file comes empty for some reason.
#   We must check that special case to avoid invalid accumulation!
#
IFS=$'\n' read -r -d '' count uniques stats_length <<< $(jq ".count,.uniques,.$stats_list_key|length" $stats_json)

(( ! count && ! uniques && ! stats_length )) && {
  print_error "$0: error: json data is invalid or empty."
  exit 255
} >&2

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

  echo "\
{
  \"timestamp\" : \"$timestamp\",
  \"count\" : $count,
  \"count_minmax\" : [ $count_min, $count_max ],
  \"uniques\" : $uniques,
  \"uniques_minmax\" : [ $uniques_min, $uniques_max ]
}" > "$year_date_json"
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
