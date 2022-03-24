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
#     * ENABLE_GENERATE_CHANGELOG_FILE
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

# Script both for execution and inclusion.
if [[ -n "$BASH" ]]; then

[[ -z "$GH_WORKFLOW_ROOT" ]] && {
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
}

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?

tkl_include "$GH_WORKFLOW_ROOT/bash/github/print-notice.sh" || tkl_abort_include
tkl_include "$GH_WORKFLOW_ROOT/bash/github/print-warning.sh" || tkl_abort_include
tkl_include "$GH_WORKFLOW_ROOT/bash/github/print-error.sh" || tkl_abort_include


CHANGELOG_BUF_STR=''

function gh_set_env_var()
{
  [[ -n "$GITHUB_ACTIONS" ]] && echo "$1=$2" >> $GITHUB_ENV
}

function gh_prepend_changelog_file()
{
  (( ! ENABLE_GENERATE_CHANGELOG_FILE )) && return 0
  [[ -z "$CHANGELOG_BUF_STR" ]] && return 0

  if [[ -f "$changelog_txt" ]]; then
    local changelog_file="${CHANGELOG_BUF_STR}"$'\r\n'"$(< "$changelog_txt")"
  else
    local changelog_file="${CHANGELOG_BUF_STR}"
  fi

  echo -n "$changelog_file" > "$changelog_txt"

  CHANGELOG_BUF_STR=''
}

[[ -z "$CONTINUE_ON_INVALID_INPUT" ]] && CONTINUE_ON_INVALID_INPUT=0
[[ -z "$CONTINUE_ON_EMPTY_CHANGES" ]] && CONTINUE_ON_EMPTY_CHANGES=0
[[ -z "$CONTINUE_ON_RESIDUAL_CHANGES" ]] && CONTINUE_ON_RESIDUAL_CHANGES=0
[[ -z "$ENABLE_GENERATE_CHANGELOG_FILE" ]] && ENABLE_GENERATE_CHANGELOG_FILE=0

if (( ENABLE_GENERATE_CHANGELOG_FILE )); then
  [[ -z "$changelog_dir" ]] && {
    gh_print_error "$0: error: \`changelog_dir\` variable must be defined."
    exit 255
  }

  [[ -z "$changelog_txt" ]] && changelog_txt="$changelog_dir/changelog.txt"
fi

tkl_set_return

fi
