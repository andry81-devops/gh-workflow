#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
[[ -z "$BASH" || (-n "$SOURCE_GHWF_PRINT_ERROR_SH" && SOURCE_GHWF_PRINT_ERROR_SH -ne 0) ]] && return

SOURCE_GHWF_PRINT_ERROR_SH=1 # including guard

[[ -z "$GH_WORKFLOW_ROOT" ]] && {
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
}

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?

tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-print-workflow.sh"


function gh_enable_print_error_buffering()
{
  [[ -z "${PRINT_ERROR_BUF_STR+x}" ]] && tkl_declare_global PRINT_ERROR_BUF_STR ''
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

# NOTE:
#   To use a single line as a multiline output you must replace all `\n` by
#   `%0A`.
#
#   For the details:
#     https://github.com/actions/toolkit/issues/193#issuecomment-605394935
#     https://github.com/actions/starter-workflows/issues/68#issuecomment-581479448
#
function gh_print_error_ln()
{
  local IFS
  local line=''
  local arg

  if [[ -n "${PRINT_ERROR_BUF_STR+x}" ]]; then
    if [[ -n "$GITHUB_ACTIONS" ]]; then
      IFS=$'\n'; for arg in "$@"; do
        line="${line}${line:+"%0D%0A"}$arg"
      done
      PRINT_ERROR_BUF_STR="${PRINT_ERROR_BUF_STR}${PRINT_ERROR_BUF_STR:+$'\r\n'}::error ::$line"
    else
      PRINT_ERROR_BUF_STR="${PRINT_ERROR_BUF_STR}${PRINT_ERROR_BUF_STR:+$'\r\n'}$*"
    fi
  else
    # with check on integer value
    [[ -n "$PRINT_ERROR_LAG_FSEC" && -z "${PRINT_ERROR_LAG_FSEC//[0-9]/}" ]] && sleep $PRINT_ERROR_LAG_FSEC

    gh_print_error_ln_nobuf_nolag "$@"
  fi
}

function gh_print_error_ln_nobuf_nolag()
{
  local IFS
  local line=''
  local arg

  # with check on integer value
  [[ -n "$PRINT_ERROR_LAG_FSEC" && -z "${PRINT_ERROR_LAG_FSEC//[0-9]/}" ]] && sleep $PRINT_ERROR_LAG_FSEC

  # fix GitHub log issue when a trailing line return charcter in the message does convert into blank line

  if [[ -n "$GITHUB_ACTIONS" ]]; then
    IFS=$'\n'; for arg in "$@"; do
      line="${line}${line:+"%0D%0A"}$arg"
    done
    gh_trim_trailing_line_return_chars "$line"
    gh_print_annotation error "::$RETURN_VALUE" >&2
  else
    gh_trim_trailing_line_return_chars "$*"
    echo "$*" >&2
  fi
}

function gh_print_errors_nobuf_nolag()
{
  local IFS
  local arg

  # with check on integer value
  [[ -n "$PRINT_ERROR_LAG_FSEC" && -z "${PRINT_ERROR_LAG_FSEC//[0-9]/}" ]] && sleep $PRINT_ERROR_LAG_FSEC

  # fix GitHub log issue when a trailing line return charcter in the message does convert into blank line

  if [[ -n "$GITHUB_ACTIONS" ]]; then
    IFS=$'\n'; for arg in "$@"; do
      gh_trim_trailing_line_return_chars "$arg"
      gh_print_annotation error "::$RETURN_VALUE" >&2
    done >&2
  else
    IFS=$'\n'; for arg in "$@"; do
      gh_trim_trailing_line_return_chars "$arg"
      echo "$RETURN_VALUE"
    done >&2
  fi
}

function gh_print_errors_nobuf_noprefix()
{
  local IFS

  # with check on integer value
  [[ -n "$PRINT_ERROR_LAG_FSEC" && -z "${PRINT_ERROR_LAG_FSEC//[0-9]/}" ]] && sleep $PRINT_ERROR_LAG_FSEC

  gh_print_args "$@" >&2

  if [[ -n "$GITHUB_ACTIONS" ]]; then
    IFS=$'\n'; for arg in "$@"; do
      gh_trim_trailing_line_return_chars "$arg"
      gh_print_annotation error "::$RETURN_VALUE" >&2
    done
  fi
}

function gh_print_errors()
{
  local IFS
  local arg

  if [[ -n "${PRINT_ERROR_BUF_STR+x}" ]]; then
    if [[ -n "$GITHUB_ACTIONS" ]]; then
      IFS=$'\n'; for arg in "$@"; do
        PRINT_ERROR_BUF_STR="${PRINT_ERROR_BUF_STR}${PRINT_ERROR_BUF_STR:+$'\r\n'}::error ::$arg"
      done
    else
      IFS=$'\n'; for arg in "$@"; do
        PRINT_ERROR_BUF_STR="${PRINT_ERROR_BUF_STR}${PRINT_ERROR_BUF_STR:+$'\r\n'}$arg"
      done
    fi
  else
    # with check on integer value
    [[ -n "$PRINT_ERROR_LAG_FSEC" && -z "${PRINT_ERROR_LAG_FSEC//[0-9]/}" ]] && sleep $PRINT_ERROR_LAG_FSEC

    if [[ -n "$GITHUB_ACTIONS" ]]; then
      gh_print_errors_nobuf_nolag "$@"
    else
      gh_print_args "$@" >&2
    fi
  fi
}

function gh_write_error_to_changelog_text_bullet_ln()
{
  (( ! ENABLE_GENERATE_CHANGELOG_FILE )) && return

  local changelog_msg="$1"

  CHANGELOG_BUF_STR="${CHANGELOG_BUF_STR}* error: ${changelog_msg}"$'\r\n'

  # update GitHub pipeline variable
  gh_set_env_var CHANGELOG_BUF_STR "$CHANGELOG_BUF_STR"
}

# format: <message> | <error_message> <changelog_message>
function gh_print_error_and_write_to_changelog_text_ln()
{
  local error_msg="$1"

  gh_print_error_ln "$error_msg"

  if (( ENABLE_GENERATE_CHANGELOG_FILE )); then
    local changelog_msg="$2"

    (( ${#@} < 2 )) && changelog_msg="$error_msg"

    gh_write_to_changelog_text_ln "$changelog_msg"
  fi
}

# format: <message> | <error_message> <changelog_message>
function gh_print_error_and_write_to_changelog_text_bullet_ln()
{
  local error_msg="$1"

  gh_print_error_ln "$error_msg"

  if (( ENABLE_GENERATE_CHANGELOG_FILE )); then
    local changelog_msg="$2"

    (( ${#@} < 2 )) && changelog_msg="$error_msg"

    gh_write_error_to_changelog_text_bullet_ln "$changelog_msg"
  fi
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  gh_print_errors "$@"
fi
