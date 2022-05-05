#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
[[ -z "$BASH" || (-n "$SOURCE_GHWF_PRINT_NOTICE_SH" && SOURCE_GHWF_PRINT_NOTICE_SH -ne 0) ]] && return

SOURCE_GHWF_PRINT_NOTICE_SH=1 # including guard

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?

tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/print.sh"


function gh_enable_print_notice_buffering()
{
  [[ -z "${PRINT_NOTICE_BUF_STR+x}" ]] && tkl_declare_global PRINT_NOTICE_BUF_STR ''
}

# NOTE:
#   To set lag to try to avoid printing notices before warning and/or errors to a log without buffering.
#
function gh_set_print_notice_lag()
{
  tkl_declare_global PRINT_NOTICE_LAG_FSEC 0

  # with check on integer value
  [[ -n "$1" && -z "${1//[0-9]/}" ]] && PRINT_NOTICE_LAG_FSEC=$1
}

# NOTE:
#   To use a single line as a multiline output you must replace all `\n` by
#   `%0A`.
#
#   For the details:
#     https://github.com/actions/toolkit/issues/193#issuecomment-605394935
#     https://github.com/actions/starter-workflows/issues/68#issuecomment-581479448
#
function gh_print_notice_ln()
{
  local IFS=$'\n'
  local line=''
  local arg

  if [[ -n "${PRINT_NOTICE_BUF_STR+x}" ]]; then
    if [[ -n "$GITHUB_ACTIONS" ]]; then
      for arg in "$@"; do
        line="${line}${line:+"%0D%0A"}$arg"
      done
      PRINT_NOTICE_BUF_STR="${PRINT_NOTICE_BUF_STR}${PRINT_NOTICE_BUF_STR:+$'\r\n'}::notice ::$line"
    else
      PRINT_NOTICE_BUF_STR="${PRINT_NOTICE_BUF_STR}${PRINT_NOTICE_BUF_STR:+$'\r\n'}$*"
    fi
  else
    # with check on integer value
    [[ -n "$PRINT_NOTICE_LAG_FSEC" && -z "${PRINT_NOTICE_LAG_FSEC//[0-9]/}" ]] && sleep $PRINT_NOTICE_LAG_FSEC

    if [[ -n "$GITHUB_ACTIONS" ]]; then
      for arg in "$@"; do
        line="${line}${line:+"%0D%0A"}$arg"
      done
      echo "::notice ::$line"
    else
      echo "$*"
    fi
  fi
}

function gh_print_notices()
{
  local IFS=$'\n'
  local arg

  if [[ -n "${PRINT_NOTICE_BUF_STR+x}" ]]; then
    if [[ -n "$GITHUB_ACTIONS" ]]; then
      for arg in "$@"; do
        PRINT_NOTICE_BUF_STR="${PRINT_NOTICE_BUF_STR}${PRINT_NOTICE_BUF_STR:+$'\r\n'}::notice ::$arg"
      done
    else
      for arg in "$@"; do
        PRINT_NOTICE_BUF_STR="${PRINT_NOTICE_BUF_STR}${PRINT_NOTICE_BUF_STR:+$'\r\n'}$arg"
      done
    fi
  else
    # with check on integer value
    [[ -n "$PRINT_NOTICE_LAG_FSEC" && -z "${PRINT_NOTICE_LAG_FSEC//[0-9]/}" ]] && sleep $PRINT_NOTICE_LAG_FSEC

    if [[ -n "$GITHUB_ACTIONS" ]]; then
      for arg in "$@"; do
        echo "::notice ::$arg"
      done
    else
      for arg in "$@"; do
        echo "$arg"
      done
    fi
  fi
}

function gh_write_notice_to_changelog_text_bullet_ln()
{
  (( ! ENABLE_GENERATE_CHANGELOG_FILE )) && return

  local changelog_msg="$1"

  CHANGELOG_BUF_STR="${CHANGELOG_BUF_STR}* notice: ${changelog_msg}"$'\r\n'
}

# format: <message> | <notice_message> <changelog_message>
function gh_print_notice_and_write_to_changelog_text_ln()
{
  local notice_msg="$1"

  gh_print_notice_ln "$notice_msg"

  if (( ENABLE_GENERATE_CHANGELOG_FILE )); then
    local changelog_msg="$2"

    (( ${#@} < 2 )) && changelog_msg="$notice_msg"

    gh_write_to_changelog_text_ln "$changelog_msg"
  fi
}

# format: <message> | <notice_message> <changelog_message>
function gh_print_notice_and_write_to_changelog_text_bullet_ln()
{
  local notice_msg="$1"

  gh_print_notice_ln "$notice_msg"

  if (( ENABLE_GENERATE_CHANGELOG_FILE )); then
    local changelog_msg="$2"

    (( ${#@} < 2 )) && changelog_msg="$notice_msg"

    gh_write_notice_to_changelog_text_bullet_ln "$changelog_msg"
  fi
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  gh_print_notices "$@"
fi
