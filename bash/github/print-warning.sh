#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
[[ -z "$BASH" || (-n "$SOURCE_GHWF_PRINT_WARNING_SH" && SOURCE_GHWF_PRINT_WARNING_SH -ne 0) ]] && return

SOURCE_GHWF_PRINT_WARNING_SH=1 # including guard

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?

tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/print.sh"


function gh_enable_print_warning_buffering()
{
  [[ -z "${PRINT_WARNING_BUF_STR+x}" ]] && tkl_declare_global PRINT_WARNING_BUF_STR ''
}

# NOTE:
#   To set lag to try to avoid printing warnings before notices and/or errors to a log without buffering.
#
function gh_set_print_warning_lag()
{
  tkl_declare_global PRINT_WARNING_LAG_FSEC 0

  # with check on integer value
  [[ -n "$1" && -z "${1//[0-9]/}" ]] && PRINT_WARNING_LAG_FSEC=$1
}

# NOTE:
#   To use a single line as a multiline output you must replace all `\n` by
#   `%0A`.
#
#   For the details:
#     https://github.com/actions/toolkit/issues/193#issuecomment-605394935
#     https://github.com/actions/starter-workflows/issues/68#issuecomment-581479448
#
function gh_print_warning_ln()
{
  local IFS=$'\n'
  local line=''
  local arg

  if [[ -n "${PRINT_WARNING_BUF_STR+x}" ]]; then
    if [[ -n "$GITHUB_ACTIONS" ]]; then
      for arg in "$@"; do
        line="${line}${line:+"%0D%0A"}$arg"
      done
      PRINT_WARNING_BUF_STR="${PRINT_WARNING_BUF_STR}${PRINT_WARNING_BUF_STR:+$'\r\n'}::warning ::$line"
    else
      PRINT_WARNING_BUF_STR="${PRINT_WARNING_BUF_STR}${PRINT_WARNING_BUF_STR:+$'\r\n'}$*"
    fi
  else
    # with check on integer value
    [[ -n "$PRINT_WARNING_LAG_FSEC" && -z "${PRINT_WARNING_LAG_FSEC//[0-9]/}" ]] && sleep $PRINT_WARNING_LAG_FSEC

    if [[ -n "$GITHUB_ACTIONS" ]]; then
      for arg in "$@"; do
        line="${line}${line:+"%0D%0A"}$arg"
      done
      echo "::warning ::$line" >&2
    else
      echo "$*" >&2
    fi
  fi
}

function gh_print_warnings()
{
  local IFS=$'\n'
  local arg

  if [[ -n "${PRINT_WARNING_BUF_STR+x}" ]]; then
    if [[ -n "$GITHUB_ACTIONS" ]]; then
      for arg in "$@"; do
        PRINT_WARNING_BUF_STR="${PRINT_WARNING_BUF_STR}${PRINT_WARNING_BUF_STR:+$'\r\n'}::warning ::$arg"
      done
    else
      for arg in "$@"; do
        PRINT_WARNING_BUF_STR="${PRINT_WARNING_BUF_STR}${PRINT_WARNING_BUF_STR:+$'\r\n'}$arg"
      done
    fi
  else
    # with check on integer value
    [[ -n "$PRINT_WARNING_LAG_FSEC" && -z "${PRINT_WARNING_LAG_FSEC//[0-9]/}" ]] && sleep $PRINT_WARNING_LAG_FSEC

    if [[ -n "$GITHUB_ACTIONS" ]]; then
      for arg in "$@"; do
        echo "::warning ::$arg" >&2
      done
    else
      for arg in "$@"; do
        echo "$arg" >&2
      done
    fi
  fi
}

function gh_write_warning_to_changelog_text_bullet_ln()
{
  (( ! ENABLE_GENERATE_CHANGELOG_FILE )) && return

  local changelog_msg="$1"

  CHANGELOG_BUF_STR="${CHANGELOG_BUF_STR}* warning: ${changelog_msg}"$'\r\n'
}

# format: <message> | <warning_message> <changelog_message>
function gh_print_warning_and_write_to_changelog_text_ln()
{
  local warning_msg="$1"

  gh_print_warning_ln "$warning_msg"

  if (( ENABLE_GENERATE_CHANGELOG_FILE )); then
    local changelog_msg="$2"

    (( ${#@} < 2 )) && changelog_msg="$warning_msg"

    gh_write_to_changelog_text_ln "$changelog_msg"
  fi
}

# format: <message> | <warning_message> <changelog_message>
function gh_print_warning_and_write_to_changelog_text_bullet_ln()
{
  local warning_msg="$1"

  gh_print_warning_ln "$warning_msg"

  if (( ENABLE_GENERATE_CHANGELOG_FILE )); then
    local changelog_msg="$2"

    (( ${#@} < 2 )) && changelog_msg="$warning_msg"

    gh_write_warning_to_changelog_text_bullet_ln "$changelog_msg"
  fi
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  gh_print_warnings "$@"
fi
