#!/bin/bash

[[ -z "$traffic_clones_json" ]] && traffic_clones_json='traffic/clones.json'
[[ -z "$traffic_clones_accum_json" ]] && traffic_clones_accum_json='traffic/clones-accum.json'

clones_accum_timestamp=()
clones_accum_count=()
clones_accum_uniques=()

IFS=$'\n' read -r -d '' count_outdated_prev uniques_outdated_prev count_prev uniques_prev <<< "$(jq -c -r ".count_outdated,.uniques_outdated,.count,.uniques" $traffic_clones_accum_json)"

for i in $(jq '.clones|keys|.[]' $traffic_clones_accum_json); do
  IFS=$'\n' read -r -d '' timestamp count uniques <<< "$(jq -c -r ".clones[$i].timestamp,.clones[$i].count,.clones[$i].uniques" $traffic_clones_accum_json)"

  clones_accum_timestamp[${#clones_accum_timestamp[@]}]="$timestamp"
  clones_accum_count[${#clones_accum_count[@]}]=$count
  clones_accum_uniques[${#clones_accum_uniques[@]}]=$uniques
done

first_clones_timestamp=""

clones_timestamp=()
clones_count=()
clones_uniques=()

for i in $(jq '.clones|keys|.[]' $traffic_clones_json); do
  IFS=$'\n' read -r -d '' timestamp count uniques <<< "$(jq -c -r ".clones[$i].timestamp,.clones[$i].count,.clones[$i].uniques" $traffic_clones_json)"

  (( ! i )) && first_clones_timestamp="$timestamp"

  clones_timestamp[${#clones_timestamp[@]}]="$timestamp"
  clones_count[${#clones_count[@]}]=$count
  clones_uniques[${#clones_uniques[@]}]=$uniques
done

# accumulate statistic
count_outdated_next=$count_outdated_prev
uniques_outdated_next=$uniques_outdated_prev

for (( i=0; i < ${#clones_accum_timestamp[@]}; i++)); do
  if [[ -z "$first_clones_timestamp" || "${clones_accum_timestamp[i]}" < "$first_clones_timestamp" ]]; then
    (( count_outdated_next += ${clones_accum_count[i]} ))
    (( uniques_outdated_next += ${clones_accum_uniques[i]} ))
  fi
done

count_next=0
uniques_next=0

for (( i=0; i < ${#clones_timestamp[@]}; i++)); do
  (( count_next += ${clones_count[i]} ))
  (( uniques_next += ${clones_uniques[i]} ))
done

(( count_next += count_outdated_next ))
(( uniques_next += uniques_outdated_next ))

(( count_outdated_prev == count_outdated_next && uniques_outdated_prev == uniques_outdated_next && \
   count_prev == count_next && uniques_prev == uniques_next )) && {
  echo "$0: warning: nothing is changed, no new clones."
  exit 255
} >&2

{
  echo -n "\
{
  \"timestamp\" : \"$(date --utc +%FT%TZ)\",
  \"count_outdated\" : $count_outdated_next,
  \"uniques_outdated\" : $uniques_outdated_next,
  \"count\" : $count_next,
  \"uniques\" : $uniques_next,
  \"clones\" : ["

  for (( i=0; i < ${#clones_timestamp[@]}; i++)); do
    (( i )) && echo -n ','
    echo ''

    echo -n "\
    {
      \"timestamp\": \"${clones_timestamp[i]}\",
      \"count\": ${clones_count[i]},
      \"uniques\": ${clones_uniques[i]}
    }"
  done

  (( i )) && echo -n '  '

  echo ']
}'
} > $traffic_clones_accum_json
