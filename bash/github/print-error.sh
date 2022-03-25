#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
if [[ -n "$BASH" ]]; then

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?


function gh_enable_print_error_buffering()
{
  tkl_declare_global PRINT_ERROR_BUF_STR ''
}

# NOTE:
#   To set lag to try to avoid printing errors before notices and/or warnings to a log without buffering.
#
function gh_set_print_error_lag()
{
  tkl_declare_global PRINT_ERROR_LAG_FSEC 0

  # with check on integer value
  [[ -n "$1" && -z "${1//[0-9]/}" ]] && PRINT_ERROR_LAG_FSEC=$1
}

function gh_print_error()
{
  if [[ -n "${PRINT_ERROR_BUF_STR+x}" ]]; then
    local arg
    if [[ -n "$GITHUB_ACTIONS" ]]; then
      for arg in "$@"; do
        PRINT_ERROR_BUF_STR="${PRINT_ERROR_BUF_STR}::error ::$arg"$'\r\n'
      done
    else
      for arg in "$@"; do
        PRINT_ERROR_BUF_STR="${PRINT_ERROR_BUF_STR}$arg"$'\r\n'
      done
    fi
  else
    # with check on integer value
    [[ -n "$PRINT_ERROR_LAG_FSEC" && -z "${PRINT_ERROR_LAG_FSEC//[0-9]/}" ]] && sleep $PRINT_ERROR_LAG_FSEC

    local arg
    if [[ -n "$GITHUB_ACTIONS" ]]; then
      for arg in "$@"; do
        echo "::error ::$arg" >&2
      done
    else
      for arg in "$@"; do
        echo "$arg" >&2
      done
    fi
  fi
}

function gh_write_error_to_changelog_text_bullet_ln()
{
  (( ! ENABLE_GENERATE_CHANGELOG_FILE )) && return

  local changelog_msg="$1"

  CHANGELOG_BUF_STR="${CHANGELOG_BUF_STR}* error: ${changelog_msg}"$'\r\n'
}

# format: <message> | <error_message> <changelog_message>
function gh_print_error_and_changelog_text_bullet_ln()
{
  local error_msg="$1"

  gh_print_error "$error_msg"

  if (( ENABLE_GENERATE_CHANGELOG_FILE )); then
    local changelog_msg="$2"

    (( ${#@} < 2 )) && changelog_msg="$error_msg"

    gh_write_error_to_changelog_text_bullet_ln "$changelog_msg"
  fi
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  gh_print_error "$@"
fi

fi
