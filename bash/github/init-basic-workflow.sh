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
#     * CONTINUE_ON_INVALID_INPUT=1
#     * CONTINUE_ON_EMPTY_CHANGES=1
#     * CONTINUE_ON_RESIDUAL_CHANGES=1
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
#     * ENABLE_GENERATE_CHANGELOG_FILE=1
#     * ENABLE_PRINT_CURL_RESPONSE_ON_ERROR=1
#     * ENABLE_COMMIT_MESSAGE_DATE_WITH_TIME=1
#     * CHANGELOG_FILE=repo/owner-of-content/repo-with-content/content-changelog.txt
#

# Script both for execution and inclusion.
[[ -z "$BASH" || (-n "$SOURCE_GHWF_INIT_BASIC_WORKFLOW_SH" && SOURCE_GHWF_INIT_BASIC_WORKFLOW_SH -ne 0) ]] && return

SOURCE_GHWF_INIT_BASIC_WORKFLOW_SH=1 # including guard

[[ -z "$GH_WORKFLOW_ROOT" ]] && {
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
}

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?

tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-print-workflow.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/utils.sh"

# does not enable or disable by default, just does include a functionality
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/enable-github-env-autoeval.sh"


function init_basic_workflow()
{
  # load GitHub Actions variables at first
  if (( GHWF_GITHUB_ENV_AUTOEVAL )); then
    gh_eval_github_env
  fi

  if [[ -z "${GHWF_CHANGELOG_BUF_STR:+x}" ]]; then # to save buffer between workflow steps
    gh_set_env_var GHWF_CHANGELOG_BUF_STR  ''
  fi

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


function gh_prepend_changelog_file()
{
  (( ! ENABLE_GENERATE_CHANGELOG_FILE )) && return 0
  [[ -z "$GHWF_CHANGELOG_BUF_STR" ]] && return 0

  if [[ -f "$CHANGELOG_FILE" && -s "$CHANGELOG_FILE" ]]; then
    local changelog_buf="${GHWF_CHANGELOG_BUF_STR}"$'\r\n'"$(< "$CHANGELOG_FILE")"
  else
    local changelog_buf="${GHWF_CHANGELOG_BUF_STR}"
  fi

  echo -n "$changelog_buf" > "$CHANGELOG_FILE"

  gh_set_env_var GHWF_CHANGELOG_BUF_STR ''
}

tkl_set_return
