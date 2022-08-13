#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
[[ -z "$BASH" || (-n "$SOURCE_GHWF_PRINT_NOTICE_SH" && SOURCE_GHWF_PRINT_NOTICE_SH -ne 0) ]] && return

SOURCE_GHWF_PRINT_NOTICE_SH=1 # including guard

[[ -z "$GH_WORKFLOW_ROOT" ]] && {
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
}

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?

tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-print-workflow.sh"


function gh_enable_print_notice_buffering()
{
  if [[ -z "${PRINT_NOTICE_BUF_STR+x}" ]]; then
    tkl_declare_global PRINT_NOTICE_BUF_STR ''
  fi
}

# NOTE:
#   To set lag to try to avoid printing notices before warnings and/or errors to a log without buffering.
#
function gh_set_print_notice_lag()
{
  tkl_declare_global PRINT_NOTICE_LAG_FSEC 0

  # with check on integer value
  if [[ -n "$1" && -z "${1//[0-9]/}" ]]; then
    PRINT_NOTICE_LAG_FSEC="$1"
  fi
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
  local line=''
  local arg

  if [[ -n "${PRINT_NOTICE_BUF_STR+x}" ]]; then
    if [[ -n "$GITHUB_ACTIONS" ]]; then
      local IFS=$'\n'; for arg in "$@"; do
        line="${line}${line:+"%0A"}$arg"
      done

      gh_trim_trailing_line_return_chars "$line"

      # fix multiline text in a single argument
      gh_encode_line_return_chars "$RETURN_VALUE"

      gh_process_annotation_print notice '' "$RETURN_VALUE"

      PRINT_NOTICE_BUF_STR="${PRINT_NOTICE_BUF_STR}${PRINT_NOTICE_BUF_STR:+"${RETURN_VALUES[0]}"}${RETURN_VALUES[1]}"
    else
      PRINT_NOTICE_BUF_STR="${PRINT_NOTICE_BUF_STR}${PRINT_NOTICE_BUF_STR:+$'\r\n'}$*"
    fi
  else
    # with check on integer value
    [[ -n "$PRINT_NOTICE_LAG_FSEC" && -z "${PRINT_NOTICE_LAG_FSEC//[0-9]/}" ]] && (( PRINT_NOTICE_LAG_FSEC > 0 )) && sleep $PRINT_NOTICE_LAG_FSEC

    gh_print_notice_ln_nobuf_nolag "$@"
  fi
}

function gh_print_notice_ln_nobuf_nolag()
{
  local line=''
  local arg

  # fix GitHub log issue when a trailing line return charcter in the message does convert into blank line

  if [[ -n "$GITHUB_ACTIONS" ]]; then
    local IFS=$'\n'; for arg in "$@"; do
      line="${line}${line:+"%0A"}$arg"
    done

    gh_trim_trailing_line_return_chars "$line"

    # fix multiline text in a single argument
    gh_encode_line_return_chars "$RETURN_VALUE"

    gh_print_annotation notice '' "$RETURN_VALUE"
  else
    gh_trim_trailing_line_return_chars "$*"

    echo "$RETURN_VALUE"
  fi
}

function gh_print_notices_nobuf_nolag()
{
  local IFS
  local arg

  # fix GitHub log issue when a trailing line return charcter in the message does convert into blank line

  if [[ -n "$GITHUB_ACTIONS" ]]; then
    IFS=$'\n'; for arg in "$@"; do
      gh_trim_trailing_line_return_chars "$arg"

      # fix multiline text in a single argument
      gh_encode_line_return_chars "$RETURN_VALUE"

      gh_print_annotation notice '' "$RETURN_VALUE"
    done
  else
    IFS=$'\n'; for arg in "$@"; do
      gh_trim_trailing_line_return_chars "$arg"

      echo "$RETURN_VALUE"
    done
  fi
}

function gh_print_notices_buffer()
{
  local buf="$1"

  local line

  # with check on integer value
  [[ -n "$PRINT_NOTICE_LAG_FSEC" && -z "${PRINT_NOTICE_LAG_FSEC//[0-9]/}" ]] && (( PRINT_NOTICE_LAG_FSEC > 0 )) && sleep $PRINT_NOTICE_LAG_FSEC

  if [[ -n "$GITHUB_ACTIONS" ]]; then
    local IFS=$'\n'; for line in "$buf"; do
      gh_trim_trailing_line_return_chars "$line"

      # fix multiline text in a single argument
      gh_encode_line_return_chars "$RETURN_VALUE"

      gh_print_annotation notice '' "$RETURN_VALUE"
    done
  else
    gh_print_args "$buf"
  fi
}

function gh_print_notices()
{
  local IFS
  local arg

  if [[ -n "${PRINT_NOTICE_BUF_STR+x}" ]]; then
    if [[ -n "$GITHUB_ACTIONS" ]]; then
      IFS=$'\n'; for arg in "$@"; do
        gh_trim_trailing_line_return_chars "$arg"

        # fix multiline text in a single argument
        gh_encode_line_return_chars "$RETURN_VALUE"

        gh_process_annotation_print notice '' "$RETURN_VALUE"

        PRINT_NOTICE_BUF_STR="${PRINT_NOTICE_BUF_STR}${PRINT_NOTICE_BUF_STR:+"${RETURN_VALUES[0]}"}${RETURN_VALUES[1]}"
      done
    else
      IFS=$'\n'; for arg in "$@"; do
        PRINT_NOTICE_BUF_STR="${PRINT_NOTICE_BUF_STR}${PRINT_NOTICE_BUF_STR:+$'\r\n'}$arg"
      done
    fi
  else
    # with check on integer value
    [[ -n "$PRINT_NOTICE_LAG_FSEC" && -z "${PRINT_NOTICE_LAG_FSEC//[0-9]/}" ]] && (( PRINT_NOTICE_LAG_FSEC > 0 )) && sleep $PRINT_NOTICE_LAG_FSEC

    if [[ -n "$GITHUB_ACTIONS" ]]; then
      gh_print_notices_nobuf_nolag "$@"
    else
      gh_print_args "$@"
    fi
  fi
}

function gh_write_notice_to_changelog_text_bullet_ln()
{
  (( ! ENABLE_GENERATE_CHANGELOG_FILE )) && return

  local changelog_msg="$1"

  CHANGELOG_BUF_STR="${CHANGELOG_BUF_STR}* notice: ${changelog_msg}"$'\r\n'

  # update GitHub pipeline variable
  gh_set_env_var CHANGELOG_BUF_STR "$CHANGELOG_BUF_STR"
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
