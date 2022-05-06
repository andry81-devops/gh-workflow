#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# NOTE:
#   Lower case variable names for a per script usage (input only).
#   Upper case variable names for use between scripts including return values.
#

# NOTE:
#   To be able to distinguish a pipeline service outage from the changes
#   absence including residual or algorithmically not actual changes you must
#   declare these variables:
#
#     * CONTINUE_ON_INVALID_INPUT
#     * CONTINUE_ON_EMPTY_CHANGES
#     * CONTINUE_ON_RESIDUAL_CHANGES
#
#   Because invalid input, empty or residual changes has to be detected and
#   has to be not trigger a commit, then we must to continue on them
#   explicitly.
#   Because empty changes does ignore by the VCS, then we must make additional
#   changes locally to be able to commit, so we create a changelog file with
#   local changes.
#   Additionally, the changelog file contains a timestamp for each script
#   execution altogether with several notices and warnings printed from the
#   script to highlight the pipeline events and basic statistic without a need
#   to compare a complete set of changes.
#
#   Other variables:
#
#     * ERROR_ON_EMPTY_CHANGES_WITHOUT_ERRORS=1
#     * ENABLE_GENERATE_CHANGELOG_FILE
#     * ENABLE_PRINT_CURL_RESPONSE_ON_ERROR
#     * ENABLE_COMMIT_MESSAGE_DATE_WITH_TIME
#     * CHANGELOG_FILE
#

# Script both for execution and inclusion.
[[ -z "$BASH" || (-n "$SOURCE_GHWF_INIT_BASIC_WORKFLOW_SH" && SOURCE_GHWF_INIT_BASIC_WORKFLOW_SH -ne 0) ]] && return

SOURCE_GHWF_INIT_BASIC_WORKFLOW_SH=1 # including guard

[[ -z "$GH_WORKFLOW_ROOT" ]] && {
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
}

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?

tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/print.sh"


function init_basic_workflow()
{
  tkl_declare_global CHANGELOG_BUF_STR ''

  gh_set_print_warning_lag  .025 # 25 msec
  gh_set_print_error_lag    .025

  [[ -z "$CONTINUE_ON_INVALID_INPUT" ]] && CONTINUE_ON_INVALID_INPUT=0
  [[ -z "$CONTINUE_ON_EMPTY_CHANGES" ]] && CONTINUE_ON_EMPTY_CHANGES=0
  [[ -z "$CONTINUE_ON_RESIDUAL_CHANGES" ]] && CONTINUE_ON_RESIDUAL_CHANGES=0
  [[ -z "$ENABLE_GENERATE_CHANGELOG_FILE" ]] && ENABLE_GENERATE_CHANGELOG_FILE=0
  [[ -z "$ENABLE_PRINT_CURL_RESPONSE_ON_ERROR" ]] && ENABLE_PRINT_CURL_RESPONSE_ON_ERROR=0
  [[ -z "$ENABLE_COMMIT_MESSAGE_DATE_WITH_TIME" ]] && ENABLE_COMMIT_MESSAGE_DATE_WITH_TIME=0

  if (( ENABLE_GENERATE_CHANGELOG_FILE )); then
    [[ -z "$CHANGELOG_FILE" ]] && CHANGELOG_FILE='changelog.txt'
  fi

  return 0
}

init_basic_workflow || exit $?


function gh_set_env_var()
{
  [[ -n "$GITHUB_ACTIONS" ]] && echo "$1=$2" >> $GITHUB_ENV
}

function gh_prepend_changelog_file()
{
  (( ! ENABLE_GENERATE_CHANGELOG_FILE )) && return 0
  [[ -z "$CHANGELOG_BUF_STR" ]] && return 0

  if [[ -f "$CHANGELOG_FILE" && -s "$CHANGELOG_FILE" ]]; then
    local changelog_buf="${CHANGELOG_BUF_STR}"$'\r\n'"$(< "$CHANGELOG_FILE")"
  else
    local changelog_buf="${CHANGELOG_BUF_STR}"
  fi

  echo -n "$changelog_buf" > "$CHANGELOG_FILE"

  CHANGELOG_BUF_STR=''
}

tkl_set_return
