#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

function print_error()
{
  [[ -n "$write_error_to_file" ]] && echo "$*" >> "$write_error_to_file"
  echo "$*" >&2
}

function print_warning()
{
  [[ -n "$write_warning_to_file" ]] && echo "$*" >> "$write_warning_to_file"
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

for i in $(jq ".$stats_list_key|keys|.[]" $stats_accum_json); do
  IFS=$'\n' read -r -d '' timestamp count uniques <<< "$(jq -c -r ".$stats_list_key[$i].timestamp,.$stats_list_key[$i].count,.$stats_list_key[$i].uniques" $stats_accum_json)"

  stats_accum_timestamp[${#stats_accum_timestamp[@]}]="$timestamp"
  stats_accum_count[${#stats_accum_count[@]}]=$count
  stats_accum_uniques[${#stats_accum_uniques[@]}]=$uniques

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

  [[ ! -d "$timestamp_year_dir" ]] && mkdir -p "$timestamp_year_dir"

  echo "\
{
  \"timestamp\" : \"$timestamp\",
  \"count\" : $count,
  \"uniques\" : $uniques
}" > "$timestamp_year_dir/$timestamp_date_utc.json"
done

# accumulate statistic
count_outdated_next=$count_outdated_prev
uniques_outdated_next=$uniques_outdated_prev

for (( i=0; i < ${#stats_accum_timestamp[@]}; i++)); do
  if [[ -z "$first_stats_timestamp" || "${stats_accum_timestamp[i]}" < "$first_stats_timestamp" ]]; then
    (( count_outdated_next += ${stats_accum_count[i]} ))
    (( uniques_outdated_next += ${stats_accum_uniques[i]} ))
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
      \"uniques\": ${stats_uniques[i]}
    }"
  done

  (( i )) && echo -e -n "\n  "

  echo ']
}'
} > $stats_accum_json || exit $?
