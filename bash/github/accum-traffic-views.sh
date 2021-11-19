#!/bin/bash

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

[[ -z "$traffic_views_dir" ]] && traffic_views_dir='traffic/views'
[[ -z "$traffic_views_by_year_dir" ]] && traffic_views_by_year_dir="$traffic_views_dir/by_year"
[[ -z "$traffic_views_json" ]] && traffic_views_json="$traffic_views_dir/latest.json"
[[ -z "$traffic_views_accum_json" ]] && traffic_views_accum_json="$traffic_views_dir/latest-accum.json"

current_date_time_utc=$(date --utc +%FT%TZ)

views_accum_timestamp=()
views_accum_count=()
views_accum_uniques=()

IFS=$'\n' read -r -d '' count_outdated_prev uniques_outdated_prev count_prev uniques_prev <<< "$(jq -c -r ".count_outdated,.uniques_outdated,.count,.uniques" $traffic_views_accum_json)"

views_timestamp_prev_seq=""
views_count_prev_seq=""
views_unique_prev_seq=""

for i in $(jq '.views|keys|.[]' $traffic_views_accum_json); do
  IFS=$'\n' read -r -d '' timestamp count uniques <<< "$(jq -c -r ".views[$i].timestamp,.views[$i].count,.views[$i].uniques" $traffic_views_accum_json)"

  views_accum_timestamp[${#views_accum_timestamp[@]}]="$timestamp"
  views_accum_count[${#views_accum_count[@]}]=$count
  views_accum_uniques[${#views_accum_uniques[@]}]=$uniques

  views_timestamp_prev_seq="$views_timestamp_prev_seq|$timestamp"
  views_count_prev_seq="$views_count_prev_seq|$count"
  views_uniques_prev_seq="$views_uniques_prev_seq|$uniques"
done

first_views_timestamp=""

views_timestamp=()
views_count=()
views_uniques=()

views_timestamp_next_seq=""
views_count_next_seq=""
views_unique_next_seq=""

for i in $(jq '.views|keys|.[]' $traffic_views_json); do
  IFS=$'\n' read -r -d '' timestamp count uniques <<< "$(jq -c -r ".views[$i].timestamp,.views[$i].count,.views[$i].uniques" $traffic_views_json)"

  (( ! i )) && first_views_timestamp="$timestamp"

  views_timestamp[${#views_timestamp[@]}]="$timestamp"
  views_count[${#views_count[@]}]=$count
  views_uniques[${#views_uniques[@]}]=$uniques

  views_timestamp_next_seq="$views_timestamp_next_seq|$timestamp"
  views_count_next_seq="$views_count_next_seq|$count"
  views_uniques_next_seq="$views_uniques_next_seq|$uniques"

  timestamp_date_time_utc=${timestamp//:/-}
  timestamp_date_utc=${timestamp_date_time_utc/%T*}
  timestamp_year_utc=${timestamp_date_utc/%-*}

  timestamp_year_dir="$traffic_views_by_year_dir/$timestamp_year_utc"

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

for (( i=0; i < ${#views_accum_timestamp[@]}; i++)); do
  if [[ -z "$first_views_timestamp" || "${views_accum_timestamp[i]}" < "$first_views_timestamp" ]]; then
    (( count_outdated_next += ${views_accum_count[i]} ))
    (( uniques_outdated_next += ${views_accum_uniques[i]} ))
  fi
done

count_next=0
uniques_next=0

for (( i=0; i < ${#views_timestamp[@]}; i++)); do
  (( count_next += ${views_count[i]} ))
  (( uniques_next += ${views_uniques[i]} ))
done

(( count_next += count_outdated_next ))
(( uniques_next += uniques_outdated_next ))

(( count_outdated_prev == count_outdated_next && uniques_outdated_prev == uniques_outdated_next && \
   count_prev == count_next && uniques_prev == uniques_next )) && [[ \
   "$views_timestamp_next_seq" == "$views_timestamp_prev_seq" && \
   "$views_count_next_seq" == "$views_count_prev_seq" && \
   "$views_uniques_next_seq" == "$views_uniques_prev_seq" ]] && {
  print_warning "$0: warning: nothing is changed, no new views."
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
  \"views\" : ["

  for (( i=0; i < ${#views_timestamp[@]}; i++)); do
    (( i )) && echo -n ','
    echo ''

    echo -n "\
    {
      \"timestamp\": \"${views_timestamp[i]}\",
      \"count\": ${views_count[i]},
      \"uniques\": ${views_uniques[i]}
    }"
  done

  (( i )) && echo -e -n "\n  "

  echo ']
}'
} > $traffic_views_accum_json || exit $?
