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

[[ -z "$stats_by_year_dir" ]] && stats_by_year_dir="$stats_dir/by_year"
[[ -z "$stats_json" ]] && stats_json="$stats_dir/latest.json"
[[ -z "$stats_accum_json" ]] && stats_accum_json="$stats_dir/latest-accum.json"

current_date_time_utc=$(date --utc +%FT%TZ)

print_notice "current date/time: $current_date_time_utc"

current_date_utc=${current_date_time_utc/%T*}

# stats between previous/next script execution (dependent to the pipeline scheduler times)

IFS=$'\n' read -r -d '' \
  stats_prev_exec_core_limit                        stats_prev_exec_core_used \
  stats_prev_exec_search_limit                      stats_prev_exec_search_used \
  stats_prev_exec_graphql_limit                     stats_prev_exec_graphql_used \
  stats_prev_exec_integration_manifest_limit        stats_prev_exec_integration_manifest_used \
  stats_prev_exec_source_import_limit               stats_prev_exec_source_import_used \
  stats_prev_exec_code_scanning_upload_limit        stats_prev_exec_code_scanning_upload_used \
  stats_prev_exec_actions_runner_registration_limit stats_prev_exec_actions_runner_registration_used \
  stats_prev_exec_scim_limit                        stats_prev_exec_scim_used \
  stats_prev_exec_rate_limit                        stats_prev_exec_rate_used \
    <<< $(jq ".resources.core.limit,.resources.core.used,\
              .resources.search.limit,.resources.search.used,\
              .resources.graphql.limit,.resources.graphql.used,\
              .resources.integration_manifest.limit,.resources.integration_manifest.used,\
              .resources.source_import.limit,.resources.source_import.used,\
              .resources.code_scanning_upload.limit,.resources.code_scanning_upload.used,\
              .resources.actions_runner_registration.limit,.resources.actions_runner_registration.used,\
              .resources.scim.limit,.resources.scim.used,\
              .rate.limit,.rate.used\
              " $stats_accum_json)

# CAUTION:
#   Prevent of invalid values spread if upstream user didn't properly commit completely correct json file or didn't commit at all.
#
[[ -z "$stats_prev_exec_core_limit" || "$stats_prev_exec_core_limit" == 'null' ]] && stats_prev_exec_core_limit=0
[[ -z "$stats_prev_exec_core_used" || "$stats_prev_exec_core_used" == 'null' ]] && stats_prev_exec_core_used=0

[[ -z "$stats_prev_exec_search_limit" || "$stats_prev_exec_search_limit" == 'null' ]] && stats_prev_exec_search_limit=0
[[ -z "$stats_prev_exec_search_used" || "$stats_prev_exec_search_used" == 'null' ]] && stats_prev_exec_search_used=0

[[ -z "$stats_prev_exec_graphql_limit" || "$stats_prev_exec_graphql_limit" == 'null' ]] && stats_prev_exec_graphql_limit=0
[[ -z "$stats_prev_exec_graphql_used" || "$stats_prev_exec_graphql_used" == 'null' ]] && stats_prev_exec_graphql_used=0

[[ -z "$stats_prev_exec_integration_manifest_limit" || "$stats_prev_exec_integration_manifest_limit" == 'null' ]] && stats_prev_exec_integration_manifest_limit=0
[[ -z "$stats_prev_exec_integration_manifest_used" || "stats_prev_exec_$integration_manifest_used" == 'null' ]] && stats_prev_exec_integration_manifest_used=0

[[ -z "$stats_prev_exec_source_import_limit" || "$stats_prev_exec_source_import_limit" == 'null' ]] && stats_prev_exec_source_import_limit=0
[[ -z "$stats_prev_exec_source_import_used" || "$stats_prev_exec_source_import_used" == 'null' ]] && stats_prev_exec_source_import_used=0

[[ -z "$stats_prev_exec_code_scanning_upload_limit" || "$stats_prev_exec_code_scanning_upload_limit" == 'null' ]] && stats_prev_exec_code_scanning_upload_limit=0
[[ -z "$stats_prev_exec_code_scanning_upload_used" || "$stats_prev_exec_code_scanning_upload_used" == 'null' ]] && stats_prev_exec_code_scanning_upload_used=0

[[ -z "$stats_prev_exec_actions_runner_registration_limit" || "$stats_prev_exec_actions_runner_registration_limit" == 'null' ]] && stats_prev_exec_actions_runner_registration_limit=0
[[ -z "$stats_prev_exec_actions_runner_registration_used" || "$stats_prev_exec_actions_runner_registration_used" == 'null' ]] && stats_prev_exec_actions_runner_registration_used=0

[[ -z "$stats_prev_exec_scim_limit" || "$stats_prev_exec_scim_limit" == 'null' ]] && stats_prev_exec_scim_limit=0
[[ -z "$stats_prev_exec_scim_used" || "$stats_prev_exec_scim_used" == 'null' ]] && stats_prev_exec_scim_used=0

[[ -z "$stats_prev_exec_rate_limit" || "$stats_prev_exec_rate_limit" == 'null' ]] && stats_prev_exec_rate_limit=0
[[ -z "$stats_prev_exec_rate_used" || "$stats_prev_exec_rate_used" == 'null' ]] && stats_prev_exec_rate_used=0

print_notice "prev: core / rate: limit used: $stats_prev_exec_core_limit $stats_prev_exec_core_used / $stats_prev_exec_rate_limit $stats_prev_exec_rate_used"

# CAUTION:
#   Sometimes the json data file comes empty for some reason.
#   We must check that special case to avoid invalid accumulation!
#
IFS=$'\n' read -r -d '' \
  core_limit                        core_used \
  search_limit                      search_used \
  graphql_limit                     graphql_used \
  integration_manifest_limit        integration_manifest_used \
  source_import_limit               source_import_used \
  code_scanning_upload_limit        code_scanning_upload_used \
  actions_runner_registration_limit actions_runner_registration_used \
  scim_limit                        scim_used \
  rate_limit                        rate_used \
  resources_length \
    <<< $(jq ".resources.core.limit,.resources.core.used,\
              .resources.search.limit,.resources.search.used,\
              .resources.graphql.limit,.resources.graphql.used,\
              .resources.integration_manifest.limit,.resources.integration_manifest.used,\
              .resources.source_import.limit,.resources.source_import.used,\
              .resources.code_scanning_upload.limit,.resources.code_scanning_upload.used,\
              .resources.actions_runner_registration.limit,.resources.actions_runner_registration.used,\
              .resources.scim.limit,.resources.scim.used,\
              .rate.limit,.rate.used,
              .resources|length\
              " $stats_json)

# CAUTION:
#   Prevent of invalid values spread if upstream user didn't properly commit completely correct json file or didn't commit at all.
#
[[ -z "$resources_length" || "$resources_length" == 'null' ]] && resources_length=0

[[ -z "$core_limit" || "$core_limit" == 'null' ]] && core_limit=0
[[ -z "$core_used" || "$core_used" == 'null' ]] && core_used=0

[[ -z "$search_limit" || "$search_limit" == 'null' ]] && search_limit=0
[[ -z "$search_used" || "$search_used" == 'null' ]] && search_used=0

[[ -z "$graphql_limit" || "$graphql_limit" == 'null' ]] && graphql_limit=0
[[ -z "$graphql_used" || "$graphql_used" == 'null' ]] && graphql_used=0

[[ -z "$integration_manifest_limit" || "$integration_manifest_limit" == 'null' ]] && integration_manifest_limit=0
[[ -z "$integration_manifest_used" || "$integration_manifest_used" == 'null' ]] && integration_manifest_used=0

[[ -z "$source_import_limit" || "$source_import_limit" == 'null' ]] && source_import_limit=0
[[ -z "$source_import_used" || "$source_import_used" == 'null' ]] && source_import_used=0

[[ -z "$code_scanning_upload_limit" || "$code_scanning_upload_limit" == 'null' ]] && code_scanning_upload_limit=0
[[ -z "$code_scanning_upload_used" || "$code_scanning_upload_used" == 'null' ]] && code_scanning_upload_used=0

[[ -z "$actions_runner_registration_limit" || "$actions_runner_registration_limit" == 'null' ]] && actions_runner_registration_limit=0
[[ -z "$actions_runner_registration_used" || "$actions_runner_registration_used" == 'null' ]] && actions_runner_registration_used=0

[[ -z "$scim_limit" || "$scim_limit" == 'null' ]] && scim_limit=0
[[ -z "$scim_used" || "$scim_used" == 'null' ]] && scim_used=0

[[ -z "$rate_limit" || "$rate_limit" == 'null' ]] && rate_limit=0
[[ -z "$rate_used" || "$rate_used" == 'null' ]] && rate_used=0

print_notice "next: core / rate: limit used: $core_limit $core_used / $rate_limit $rate_used"

timestamp_date_utc=$current_date_utc
timestamp_year_utc=${current_date_utc/%-*}
timestamp_year_dir="$stats_by_year_dir/$timestamp_year_utc"
year_date_json="$timestamp_year_dir/$timestamp_date_utc.json"

has_changes=0

if (( core_limit != stats_prev_exec_core_limit || core_used != stats_prev_exec_core_used || \
      search_limit != stats_prev_exec_search_limit || search_used != stats_prev_exec_search_used || \
      graphql_limit != stats_prev_exec_graphql_limit || graphql_used != stats_prev_exec_graphql_used || \
      integration_manifest_limit != stats_prev_exec_integration_manifest_limit || integration_manifest_used != stats_prev_exec_integration_manifest_used || \
      source_import_limit != stats_prev_exec_source_import_limit || source_import_used != stats_prev_exec_source_import_used || \
      code_scanning_upload_limit != stats_prev_exec_code_scanning_upload_limit || code_scanning_upload_used != stats_prev_exec_code_scanning_upload_used || \
      actions_runner_registration_limit != stats_prev_exec_actions_runner_registration_limit || actions_runner_registration_used != stats_prev_exec_actions_runner_registration_used || \
      scim_limit != stats_prev_exec_scim_limit || scim_used != stats_prev_exec_scim_used || \
      rate_limit != stats_prev_exec_rate_limit || rate_used != stats_prev_exec_rate_used )); then
  has_changes=1

  [[ ! -d "$timestamp_year_dir" ]] && mkdir -p "$timestamp_year_dir"

  cp -f -T $stats_json $stats_accum_json
  cp -f -T $stats_json $year_date_json
fi

stats_prev_exec_rate_limit_inc=0
stats_prev_exec_rate_limit_dec=0
stats_prev_exec_rate_used_inc=0
stats_prev_exec_rate_used_dec=0

(( rate_limit > stats_prev_exec_rate_limit )) && (( stats_prev_exec_rate_limit_inc=rate_limit-stats_prev_exec_rate_limit ))
(( rate_limit < stats_prev_exec_rate_limit )) && (( stats_prev_exec_rate_limit_dec=stats_prev_exec_rate_limit-rate_limit ))

(( rate_used > stats_prev_exec_rate_used )) && (( stats_prev_exec_rate_used_inc=rate_used-stats_prev_exec_rate_used ))
(( rate_used < stats_prev_exec_rate_used )) && (( stats_prev_exec_rate_used_dec=stats_prev_exec_rate_used-rate_used ))

print_notice "prev json diff: rate.limit rate.used: +$stats_prev_exec_rate_limit_inc +$stats_prev_exec_rate_used_inc / -$stats_prev_exec_rate_limit_dec -$stats_prev_exec_rate_used_dec"

if (( resources_length != 8 || \
      !core_limit || !search_limit || !graphql_limit || !integration_manifest_limit || \
      !source_import_limit || !code_scanning_upload_limit || !actions_runner_registration_limit || !scim_limit || \
      !rate_limit )); then
  print_error "$0: error: json data is invalid or empty or format is changed."

  # try to request json generic response fields to print them as a notice
  IFS=$'\n' read -r -d '' json_message json_url json_documentation_url <<< $(jq ".message,.url,.documentation_url" $stats_json)

  [[ "$json_message" == 'null' ]] && json_message=''
  [[ "$json_url" == 'null' ]] && json_url=''
  [[ "$json_documentation_url" == 'null' ]] && json_documentation_url=''

  [[ -n "$json_message" ]] && print_notice "json generic response: message: \`$json_message\`"
  [[ -n "$json_url" ]] && print_notice "json generic response: url: \`$json_url\`"
  [[ -n "$json_documentation_url" ]] && print_notice "json generic response: documentation_url: \`$json_documentation_url\`"

  exit 255
fi

if (( !has_changes )); then
  print_warning "$0: warning: nothing is changed, no new statistic."
  exit 255
fi

# return output variables

# CAUTION:
#   We must explicitly state the statistic calculation time in the script, because
#   the time taken from a script and the time set to commit changes ARE DIFFERENT
#   and may be shifted to the next day.
#
set_env_var STATS_DATE_UTC                    "$current_date_utc"
set_env_var STATS_DATE_TIME_UTC               "$current_date_time_utc"

set_env_var STATS_PREV_EXEC_RATE_LIMIT_INC    "$stats_prev_exec_rate_limit_inc"
set_env_var STATS_PREV_EXEC_RATE_USED_INC     "$stats_prev_exec_rate_used_inc"
set_env_var STATS_PREV_EXEC_RATE_LIMIT_DEC    "$stats_prev_exec_rate_limit_dec"
set_env_var STATS_PREV_EXEC_RATE_USED_DEC     "$stats_prev_exec_rate_used_dec"

set_env_var COMMIT_MESSAGE_SUFFIX             " | limit used: +$stats_prev_exec_rate_limit_inc +$stats_prev_exec_rate_used_inc / -$stats_prev_exec_rate_limit_dec -$stats_prev_exec_rate_used_dec"
