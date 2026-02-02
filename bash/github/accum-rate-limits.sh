#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
[[ -n "$BASH" ]] || return 0 || exit 0 # exit to avoid continue if the return can not be called

# check inclusion guard if script is included
[[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]] || (( ! SOURCE_GHWF_ACCUM_RATE_LIMITS_SH )) || return 0 || exit 0 # exit to avoid continue if the return can not be called

SOURCE_GHWF_ACCUM_RATE_LIMITS_SH=1 # including guard

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

! tkl_get_include_nest_level || tkl_execute_calls -s gh || exit $? # execute init functions only after the last include and exit on first error


function gh_accum_rate_limits()
{
  if [[ -z "$stat_entity" ]]; then
    gh_print_error_ln "$0: error: \`stat_entity\` variable is not defined."
    exit 255
  fi

  local IFS

  [[ -n "$stats_by_year_dir" ]] || stats_by_year_dir="$stats_dir/by_year"
  [[ -n "$stats_json" ]] || stats_json="$stats_dir/latest.json"
  [[ -n "$stats_accum_json" ]] || stats_accum_json="$stats_dir/latest-accum.json"

  [[ -n "$commit_msg_entity" ]] || commit_msg_entity="$stat_entity"

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
      "Stats Output Repository: $GHWF_REPO_STATS_COMMITS_URL&time_zone=utc&until=$repo_stats_commits_url_until_date_utc_day"
  fi

  # stats between previous/next script execution (dependent to the pipeline scheduler times)

  IFS=$'\n' read -r -d '' \
    stats_prev_exec_core_limit                        stats_prev_exec_core_used \
    stats_prev_exec_search_limit                      stats_prev_exec_search_used \
    stats_prev_exec_graphql_limit                     stats_prev_exec_graphql_used \
    stats_prev_exec_integration_manifest_limit        stats_prev_exec_integration_manifest_used \
    stats_prev_exec_source_import_limit               stats_prev_exec_source_import_used \
    stats_prev_exec_code_scanning_upload_limit        stats_prev_exec_code_scanning_upload_used \
    stats_prev_exec_code_scanning_autofix_limit       stats_prev_exec_code_scanning_autofix_used \
    stats_prev_exec_actions_runner_registration_limit stats_prev_exec_actions_runner_registration_used \
    stats_prev_exec_scim_limit                        stats_prev_exec_scim_used \
    stats_prev_exec_dependency_snapshots_limit        stats_prev_exec_dependency_snapshots_used \
    stats_prev_exec_dependency_sbom_limit             stats_prev_exec_dependency_sbom_used \
    stats_prev_exec_audit_log_limit                   stats_prev_exec_audit_log_used \
    stats_prev_exec_audit_log_streaming_limit         stats_prev_exec_audit_log_streaming_used \
    stats_prev_exec_code_search_limit                 stats_prev_exec_code_search_used \
    stats_prev_exec_rate_limit                        stats_prev_exec_rate_used \
      <<< $(jq ".resources.core.limit,.resources.core.used,\
                .resources.search.limit,.resources.search.used,\
                .resources.graphql.limit,.resources.graphql.used,\
                .resources.integration_manifest.limit,.resources.integration_manifest.used,\
                .resources.source_import.limit,.resources.source_import.used,\
                .resources.code_scanning_upload.limit,.resources.code_scanning_upload.used,\
                .resources.code_scanning_autofix.limit,.resources.code_scanning_autofix.used,\
                .resources.actions_runner_registration.limit,.resources.actions_runner_registration.used,\
                .resources.scim.limit,.resources.scim.used,\
                .resources.dependency_snapshots.limit,.resources.dependency_snapshots.used,\
                .resources.dependency_sbom.limit,.resources.dependency_sbom.used,\
                .resources.audit_log.limit,.resources.audit_log.used,\
                .resources.audit_log_streaming.limit,.resources.audit_log_streaming.used,\
                .resources.code_search.limit,.resources.code_search.used,\
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
    stats_prev_exec_code_scanning_autofix_limit:0 stats_prev_exec_code_scanning_autofix_used:0 \
    stats_prev_exec_actions_runner_registration_limit:0 stats_prev_exec_actions_runner_registration_used:0 \
    stats_prev_exec_scim_limit:0 stats_prev_exec_scim_used:0 \
    stats_prev_exec_dependency_snapshots_limit:0 stats_prev_exec_dependency_snapshots_used:0 \
    stats_prev_exec_dependency_sbom_limit:0 stats_prev_exec_dependency_sbom_used:0 \
    stats_prev_exec_audit_log_limit:0 stats_prev_exec_audit_log_used:0 \
    stats_prev_exec_audit_log_streaming_limit:0 stats_prev_exec_audit_log_streaming_used:0 \
    stats_prev_exec_code_search_limit:0 stats_prev_exec_code_search_used:0 \
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
    code_scanning_autofix_limit       code_scanning_autofix_used \
    actions_runner_registration_limit actions_runner_registration_used \
    scim_limit                        scim_used \
    dependency_snapshots_limit        dependency_snapshots_used \
    dependency_sbom_limit             dependency_sbom_used \
    audit_log_limit                   audit_log_used \
    audit_log_streaming_limit         audit_log_streaming_used \
    code_search_limit                 code_search_used \
    rate_limit                        rate_used \
    resources_length \
      <<< $(jq ".resources.core.limit,.resources.core.used,\
                .resources.search.limit,.resources.search.used,\
                .resources.graphql.limit,.resources.graphql.used,\
                .resources.integration_manifest.limit,.resources.integration_manifest.used,\
                .resources.source_import.limit,.resources.source_import.used,\
                .resources.code_scanning_upload.limit,.resources.code_scanning_upload.used,\
                .resources.code_scanning_autofix.limit,.resources.code_scanning_autofix.used,\
                .resources.actions_runner_registration.limit,.resources.actions_runner_registration.used,\
                .resources.scim.limit,.resources.scim.used,\
                .resources.dependency_snapshots.limit,.resources.dependency_snapshots.used,\
                .resources.dependency_sbom.limit,.resources.dependency_sbom.used,\
                .resources.audit_log.limit,.resources.audit_log.used,\
                .resources.audit_log_streaming.limit,.resources.audit_log_streaming.used,\
                .resources.code_search.limit,.resources.code_search.used,\
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
    code_scanning_autofix_limit:0 code_scanning_autofix_used:0 \
    actions_runner_registration_limit:0 actions_runner_registration_used:0 \
    scim_limit:0 scim_used:0 \
    dependency_snapshots_limit:0 dependency_snapshots_used:0 \
    dependency_sbom_limit:0 dependency_sbom_used:0 \
    audit_log_limit:0 audit_log_used:0 \
    audit_log_streaming_limit:0 audit_log_streaming_used:0 \
    code_search_limit:0 code_search_used:0 \
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
        code_scanning_autofix_limit != stats_prev_exec_code_scanning_autofix_limit || code_scanning_autofix_used != stats_prev_exec_code_scanning_autofix_used || \
        actions_runner_registration_limit != stats_prev_exec_actions_runner_registration_limit || actions_runner_registration_used != stats_prev_exec_actions_runner_registration_used || \
        scim_limit != stats_prev_exec_scim_limit || scim_used != stats_prev_exec_scim_used || \
        dependency_snapshots_limit != stats_prev_exec_dependency_snapshots_limit || dependency_snapshots_used != stats_prev_exec_dependency_snapshots_used || \
        dependency_sbom_limit != stats_prev_exec_dependency_sbom_limit || dependency_sbom_used != stats_prev_exec_dependency_sbom_used || \
        audit_log_limit != stats_prev_exec_audit_log_limit || audit_log_used != stats_prev_exec_audit_log_used || \
        audit_log_streaming_limit != stats_prev_exec_audit_log_streaming_limit || audit_log_streaming_used != stats_prev_exec_audit_log_streaming_used || \
        code_search_limit != stats_prev_exec_code_search_limit || code_search_used != stats_prev_exec_code_search_used || \
        rate_limit != stats_prev_exec_rate_limit || rate_used != stats_prev_exec_rate_used )); then
    has_changes=1

    [[ -d "$timestamp_year_dir" ]] || mkdir -p "$timestamp_year_dir"

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

  if (( graphql_limit > stats_prev_exec_graphql_limit )); then (( stats_prev_exec_graphql_limit_inc=graphql_limit-stats_prev_exec_graphql_limit )); fi
  if (( graphql_limit < stats_prev_exec_graphql_limit )); then (( stats_prev_exec_graphql_limit_dec=stats_prev_exec_graphql_limit-graphql_limit )); fi

  if (( graphql_used > stats_prev_exec_graphql_used )); then (( stats_prev_exec_graphql_used_inc=graphql_used-stats_prev_exec_graphql_used )); fi
  if (( graphql_used < stats_prev_exec_graphql_used )); then (( stats_prev_exec_graphql_used_dec=stats_prev_exec_graphql_used-graphql_used )); fi

  if (( rate_limit > stats_prev_exec_rate_limit )); then (( stats_prev_exec_rate_limit_inc=rate_limit-stats_prev_exec_rate_limit )); fi
  if (( rate_limit < stats_prev_exec_rate_limit )); then (( stats_prev_exec_rate_limit_dec=stats_prev_exec_rate_limit-rate_limit )); fi

  if (( rate_used > stats_prev_exec_rate_used )); then (( stats_prev_exec_rate_used_inc=rate_used-stats_prev_exec_rate_used )); fi
  if (( rate_used < stats_prev_exec_rate_used )); then (( stats_prev_exec_rate_used_dec=stats_prev_exec_rate_used-rate_used )); fi

  gh_print_notice_and_write_to_changelog_text_bullet_ln \
    "prev exec diff: graphql / rate: limit used: +$stats_prev_exec_graphql_limit_inc +$stats_prev_exec_graphql_used_inc -$stats_prev_exec_graphql_limit_dec -$stats_prev_exec_graphql_used_dec / +$stats_prev_exec_rate_limit_inc +$stats_prev_exec_rate_used_inc -$stats_prev_exec_rate_limit_dec -$stats_prev_exec_rate_used_dec"

  if (( resources_length != 14 || \
        ! core_limit || ! search_limit || ! graphql_limit || ! integration_manifest_limit || ! source_import_limit || \
        ! code_scanning_upload_limit || ! code_scanning_autofix_limit || ! actions_runner_registration_limit || ! scim_limit || \
        ! dependency_snapshots_limit || ! dependency_sbom_limit || ! audit_log_limit || ! audit_log_streaming_limit || \
        ! code_search_limit || ! rate_limit )); then
    gh_enable_print_buffering

    gh_print_warning_and_write_to_changelog_text_bullet_ln \
      "$0: warning: json data is invalid or empty or format is changed (known: 10; found: $resources_length)." \
      "json data is invalid or empty or format is changed (known: 10; found: $resources_length)"

    # try to request json generic response fields to print them as a notice
    IFS=$'\n' read -r -d '' json_message json_url json_documentation_url <<< $(jq ".message,.url,.documentation_url" $stats_json)

    jq_fix_null \
      json_message \
      json_url \
      json_documentation_url

    [[ -z "$json_message" ]] || gh_print_notice_and_write_to_changelog_text_bullet_ln "json generic response: message: \`$json_message\`"
    [[ -z "$json_url" ]] || gh_print_notice_and_write_to_changelog_text_bullet_ln "json generic response: url: \`$json_url\`"
    [[ -z "$json_documentation_url" ]] || gh_print_notice_and_write_to_changelog_text_bullet_ln "json generic response: documentation_url: \`$json_documentation_url\`"

    (( CONTINUE_ON_INVALID_INPUT )) || exit 255
  fi

  if (( ! has_changes )); then
    gh_enable_print_buffering

    gh_print_warning_and_write_to_changelog_text_bullet_ln "$0: warning: nothing is changed, no new statistic." "nothing is changed, no new statistic"

    (( CONTINUE_ON_EMPTY_CHANGES )) || exit 255
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
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  gh_accum_rate_limits "$@"
fi

tkl_set_return
