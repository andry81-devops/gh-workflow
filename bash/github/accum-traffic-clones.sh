#!/bin/bash

[[ -z "$traffic_clones_json" ]] && traffic_clones_json='traffic/clones.json'
[[ -z "$traffic_clones_accum_json" ]] && traffic_clones_accum_json='traffic/clones-accum.json'

# accumulate statistic
IFS=$'\n' read -r -d '' last_timestamp count_accum uniques_accum <<< "$(jq -c -r ".timestamp,.count,.uniques" $traffic_clones_accum_json)"

for i in $(jq '.clones|keys|.[]' $traffic_clones_json); do
  IFS=$'\n' read -r -d '' timestamp count uniques <<< "$(jq -c -r ".clones[$i].timestamp,.clones[$i].count,.clones[$i].uniques" $traffic_clones_json)"

  if [[ "$last_timestamp" < "$timestamp" ]]; then
    (( count_accum += count ))
    (( uniques_accum += uniques ))
    last_timestamp="$timestamp"
  fi
done

cat << EOF > $traffic_clones_accum_json
{
  "timestamp" : "$last_timestamp",
  "count" : $count_accum,
  "uniques" : $uniques_accum
}
EOF
