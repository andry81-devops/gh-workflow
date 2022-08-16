#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

[[ -z "$GH_WORKFLOW_ROOT" ]] && {
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
}

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?

tkl_include_or_abort "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/traplib.sh"

tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-basic-workflow.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-stats-workflow.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-jq-workflow.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-tacklelib-workflow.sh"


[[ -z "$stat_entity" ]] && {
  gh_print_error_ln "$0: error: \`stat_entity\` variable is not defined."
  exit 255
}

[[ -z "$stats_by_year_dir" ]] && stats_by_year_dir="$stats_dir/by_year"
[[ -z "$stats_json" ]] && stats_json="$stats_dir/latest.json"
[[ -z "$stats_accum_json" ]] && stats_accum_json="$stats_dir/latest-accum.json"

[[ -z "$commit_msg_entity" ]] && commit_msg_entity="$stat_entity"

current_date_time_utc="$(date --utc +%FT%TZ)"

# on exit handler
tkl_push_trap 'gh_flush_print_buffers; gh_prepend_changelog_file' EXIT

gh_print_notice_and_write_to_changelog_text_ln "current date/time: $current_date_time_utc" "$current_date_time_utc:"

current_date_utc="${current_date_time_utc/%T*}"

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
  stats_prev_exec_dependency_snapshots_limit        stats_prev_exec_dependency_snapshots_used \
  stats_prev_exec_rate_limit                        stats_prev_exec_rate_used \
    <<< $(jq ".resources.core.limit,.resources.core.used,\
              .resources.search.limit,.resources.search.used,\
              .resources.graphql.limit,.resources.graphql.used,\
              .resources.integration_manifest.limit,.resources.integration_manifest.used,\
              .resources.source_import.limit,.resources.source_import.used,\
              .resources.code_scanning_upload.limit,.resources.code_scanning_upload.used,\
              .resources.actions_runner_registration.limit,.resources.actions_runner_registration.used,\
              .resources.scim.limit,.resources.scim.used,\
              .resources.dependency_snapshots.limit,.resources.dependency_snapshots.used,\
              .rate.limit,.rate.used\
              " $stats_accum_json)

# CAUTION:
#   Prevent of invalid values spread if upstream user didn't properly commit completely correct json file or didn't commit at all.
#
jq_fix_null \
  replies_saved:0 views_saved:0 replies_prev_day_inc_saved:0 views_prev_day_inc_saved:0 \
  stats_prev_exec_core_limit:0 stats_prev_exec_core_used:0 \
  stats_prev_exec_search_limit:0 stats_prev_exec_search_used:0 \
  stats_prev_exec_graphql_limit:0 stats_prev_exec_graphql_used:0 \
  stats_prev_exec_integration_manifest_limit:0 stats_prev_exec_integration_manifest_used:0 \
  stats_prev_exec_source_import_limit:0 stats_prev_exec_source_import_used:0 \
  stats_prev_exec_code_scanning_upload_limit:0 stats_prev_exec_code_scanning_upload_used:0 \
  stats_prev_exec_actions_runner_registration_limit:0 stats_prev_exec_actions_runner_registration_used:0 \
  stats_prev_exec_scim_limit:0 stats_prev_exec_scim_used:0 \
  stats_prev_exec_dependency_snapshots_limit:0 stats_prev_exec_dependency_snapshots_used:0 \
  stats_prev_exec_rate_limit:0 stats_prev_exec_rate_used:0

gh_print_notice_ln "prev: graphql / rate: limit used: $stats_prev_exec_graphql_limit $stats_prev_exec_graphql_used / $stats_prev_exec_rate_limit $stats_prev_exec_rate_used"

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
  dependency_snapshots_limit        dependency_snapshots_used \
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
              .resources.dependency_snapshots.limit,.resources.dependency_snapshots.used,\
              .rate.limit,.rate.used,
              .resources|length\
              " $stats_json)

# CAUTION:
#   Prevent of invalid values spread if upstream user didn't properly commit completely correct json file or didn't commit at all.
#
jq_fix_null \
  resources_length:0 \
  core_limit:0 core_used:0 \
  search_limit:0 search_used:0  \
  graphql_limit:0 graphql_used:0 \
  integration_manifest_limit:0 integration_manifest_used:0 \
  source_import_limit:0 source_import_used:0 \
  code_scanning_upload_limit:0 code_scanning_upload_used:0 \
  actions_runner_registration_limit:0 actions_runner_registration_used:0 \
  scim_limit:0 scim_used:0 \
  dependency_snapshots_limit:0 dependency_snapshots_used:0 \
  rate_limit:0 rate_used:0

gh_print_notice_ln "next: graphql / rate: limit used: $graphql_limit $graphql_used / $rate_limit $rate_used"

gh_write_notice_to_changelog_text_bullet_ln \
  "prev // next: graphql / rate: limit used: $stats_prev_exec_graphql_limit $stats_prev_exec_graphql_used / $stats_prev_exec_rate_limit $stats_prev_exec_rate_used // $graphql_limit $graphql_used / $rate_limit $rate_used"

timestamp_date_utc="$current_date_utc"
timestamp_year_utc="${current_date_utc/%-*}"
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
      dependency_snapshots_limit != stats_prev_exec_dependency_snapshots_limit || dependency_snapshots_used != stats_prev_exec_dependency_snapshots_used || \
      rate_limit != stats_prev_exec_rate_limit || rate_used != stats_prev_exec_rate_used )); then
  has_changes=1

  [[ ! -d "$timestamp_year_dir" ]] && mkdir -p "$timestamp_year_dir"

  cp -f -T $stats_json $stats_accum_json
  cp -f -T $stats_json $year_date_json
fi

stats_prev_exec_graphql_limit_inc=0
stats_prev_exec_graphql_limit_dec=0
stats_prev_exec_graphql_used_inc=0
stats_prev_exec_graphql_used_dec=0

stats_prev_exec_rate_limit_inc=0
stats_prev_exec_rate_limit_dec=0
stats_prev_exec_rate_used_inc=0
stats_prev_exec_rate_used_dec=0

(( graphql_limit > stats_prev_exec_graphql_limit )) && (( stats_prev_exec_graphql_limit_inc=graphql_limit-stats_prev_exec_graphql_limit ))
(( graphql_limit < stats_prev_exec_graphql_limit )) && (( stats_prev_exec_graphql_limit_dec=stats_prev_exec_graphql_limit-graphql_limit ))

(( graphql_used > stats_prev_exec_graphql_used )) && (( stats_prev_exec_graphql_used_inc=graphql_used-stats_prev_exec_graphql_used ))
(( graphql_used < stats_prev_exec_graphql_used )) && (( stats_prev_exec_graphql_used_dec=stats_prev_exec_graphql_used-graphql_used ))

(( rate_limit > stats_prev_exec_rate_limit )) && (( stats_prev_exec_rate_limit_inc=rate_limit-stats_prev_exec_rate_limit ))
(( rate_limit < stats_prev_exec_rate_limit )) && (( stats_prev_exec_rate_limit_dec=stats_prev_exec_rate_limit-rate_limit ))

(( rate_used > stats_prev_exec_rate_used )) && (( stats_prev_exec_rate_used_inc=rate_used-stats_prev_exec_rate_used ))
(( rate_used < stats_prev_exec_rate_used )) && (( stats_prev_exec_rate_used_dec=stats_prev_exec_rate_used-rate_used ))

gh_print_notice_and_write_to_changelog_text_bullet_ln \
  "prev exec diff: graphql / rate: limit used: +$stats_prev_exec_graphql_limit_inc +$stats_prev_exec_graphql_used_inc -$stats_prev_exec_graphql_limit_dec -$stats_prev_exec_graphql_used_dec / +$stats_prev_exec_rate_limit_inc +$stats_prev_exec_rate_used_inc -$stats_prev_exec_rate_limit_dec -$stats_prev_exec_rate_used_dec"

if (( resources_length != 9 || \
      ! core_limit || ! search_limit || ! graphql_limit || ! integration_manifest_limit || \
      ! source_import_limit || ! code_scanning_upload_limit || ! actions_runner_registration_limit || ! scim_limit || ! dependency_snapshots_limit || \
      ! rate_limit )); then
  gh_enable_print_buffering

  gh_print_warning_and_write_to_changelog_text_bullet_ln "$0: warning: json data is invalid or empty or format is changed." "json data is invalid or empty or format is changed"

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
fi

if (( ! has_changes )); then
  gh_enable_print_buffering

  gh_print_warning_and_write_to_changelog_text_bullet_ln "$0: warning: nothing is changed, no new statistic." "nothing is changed, no new statistic"

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

gh_set_env_var STATS_PREV_EXEC_RATE_LIMIT_INC     "$stats_prev_exec_rate_limit_inc"
gh_set_env_var STATS_PREV_EXEC_RATE_USED_INC      "$stats_prev_exec_rate_used_inc"
gh_set_env_var STATS_PREV_EXEC_RATE_LIMIT_DEC     "$stats_prev_exec_rate_limit_dec"
gh_set_env_var STATS_PREV_EXEC_RATE_USED_DEC      "$stats_prev_exec_rate_used_dec"

gh_set_env_var COMMIT_MESSAGE_DATE_TIME_PREFIX    "$commit_message_date_time_prefix"

gh_set_env_var COMMIT_MESSAGE_PREFIX              "gql / rt: used: +$stats_prev_exec_graphql_used_inc -$stats_prev_exec_graphql_used_dec / +$stats_prev_exec_rate_used_inc -$stats_prev_exec_rate_used_dec"
gh_set_env_var COMMIT_MESSAGE_SUFFIX              "$commit_msg_entity"

tkl_set_return
