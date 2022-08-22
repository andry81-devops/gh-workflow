#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
[[ -z "$BASH" || (-n "$SOURCE_GHWF_PRINT_WARNING_SH" && SOURCE_GHWF_PRINT_WARNING_SH -ne 0) ]] && return

SOURCE_GHWF_PRINT_WARNING_SH=1 # including guard

[[ -z "$GH_WORKFLOW_ROOT" ]] && {
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
}

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?

tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-print-workflow.sh"


function gh_enable_print_warning_buffering()
{
  if [[ -z "${GHWF_PRINT_WARNING_BUF_STR+x}" ]]; then
    gh_set_env_var GHWF_PRINT_WARNING_BUF_STR ''
  fi
}

# NOTE:
#   To set lag to try to avoid printing warnings before notices and/or errors to a log without buffering.
#
function gh_set_print_warning_lag()
{
  tkl_declare_global PRINT_WARNING_LAG_FSEC 0

  # with check on integer value
  if [[ -n "$1" && -z "${1//[0-9]/}" ]]; then
    PRINT_WARNING_LAG_FSEC="$1"
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
function gh_print_warning_ln()
{
  local line=''
  local arg

  if [[ -n "${GHWF_PRINT_WARNING_BUF_STR+x}" ]]; then
    if [[ -n "$GITHUB_ACTIONS" ]]; then
      local IFS=$'\n'; for arg in "$@"; do
        line="${line}${line:+"%0D%0A"}$arg"
      done

      gh_trim_trailing_line_return_chars "$line"

      # fix multiline text in a single argument
      gh_encode_line_return_chars "$RETURN_VALUE"

      gh_process_annotation_print warning '' "$RETURN_VALUE"

      gh_set_env_var GHWF_PRINT_WARNING_BUF_STR "${GHWF_PRINT_WARNING_BUF_STR}${GHWF_PRINT_WARNING_BUF_STR:+"${RETURN_VALUES[0]}"}${RETURN_VALUES[1]}"
    else
      gh_set_env_var GHWF_PRINT_WARNING_BUF_STR "${GHWF_PRINT_WARNING_BUF_STR}${GHWF_PRINT_WARNING_BUF_STR:+$'\r\n'}$*"
    fi
  else
    # with check on integer value
    [[ -n "$PRINT_WARNING_LAG_FSEC" && -z "${PRINT_WARNING_LAG_FSEC//[0-9]/}" ]] && (( PRINT_WARNING_LAG_FSEC > 0 )) && sleep $PRINT_WARNING_LAG_FSEC

    gh_print_warning_ln_nobuf_nolag "$@"
  fi
}

function gh_print_warning_ln_nobuf_nolag()
{
  local line=''
  local arg

  # fix GitHub log issue when a trailing line return charcter in the message does convert into blank line

  if [[ -n "$GITHUB_ACTIONS" ]]; then
    local IFS=$'\n'; for arg in "$@"; do
      line="${line}${line:+"%0D%0A"}$arg"
    done

    gh_trim_trailing_line_return_chars "$line"

    # fix multiline text in a single argument
    gh_encode_line_return_chars "$RETURN_VALUE"

    gh_print_annotation warning '' "$RETURN_VALUE" >&2
  else
    gh_trim_trailing_line_return_chars "$*"

    echo "$RETURN_VALUE" >&2
  fi
}

function gh_print_warnings_nobuf_nolag()
{
  local IFS
  local arg

  # fix GitHub log issue when a trailing line return charcter in the message does convert into blank line

  if [[ -n "$GITHUB_ACTIONS" ]]; then
    IFS=$'\n'; for arg in "$@"; do
      gh_trim_trailing_line_return_chars "$arg"

      # fix multiline text in a single argument
      gh_encode_line_return_chars "$RETURN_VALUE"

      gh_print_annotation warning '' "$RETURN_VALUE"
    done >&2
  else
    IFS=$'\n'; for arg in "$@"; do
      gh_trim_trailing_line_return_chars "$arg"

      echo "$RETURN_VALUE"
    done >&2
  fi
}

function gh_print_warnings_buffer()
{
  local buf="$1"

  [[ -z "$buf" ]] && return 0

  local IFS
  local line

  # with check on integer value
  [[ -n "$PRINT_WARNING_LAG_FSEC" && -z "${PRINT_WARNING_LAG_FSEC//[0-9]/}" ]] && (( PRINT_WARNING_LAG_FSEC > 0 )) && sleep $PRINT_WARNING_LAG_FSEC

  if [[ -n "$GITHUB_ACTIONS" ]]; then
    while IFS=$'\n' read -r line; do
      gh_trim_trailing_line_return_chars "$line"

      # fix multiline text in a single argument
      gh_encode_line_return_chars "$RETURN_VALUE"

      gh_print_annotation_line "$RETURN_VALUE"
    done < "$buf" >&2
  else
    gh_print_args "$buf" >&2
  fi
}

function gh_print_warnings()
{
  local IFS
  local arg

  if [[ -n "${GHWF_PRINT_WARNING_BUF_STR+x}" ]]; then
    if [[ -n "$GITHUB_ACTIONS" ]]; then
      IFS=$'\n'; for arg in "$@"; do
        gh_trim_trailing_line_return_chars "$arg"

        # fix multiline text in a single argument
        gh_encode_line_return_chars "$RETURN_VALUE"

        gh_process_annotation_print warning '' "$RETURN_VALUE"

        gh_set_env_var  GHWF_PRINT_WARNING_BUF_STR "${GHWF_PRINT_WARNING_BUF_STR}${GHWF_PRINT_WARNING_BUF_STR:+"${RETURN_VALUES[0]}"}${RETURN_VALUES[1]}"
      done
    else
      IFS=$'\n'; for arg in "$@"; do
        gh_set_env_var GHWF_PRINT_WARNING_BUF_STR "${GHWF_PRINT_WARNING_BUF_STR}${GHWF_PRINT_WARNING_BUF_STR:+$'\r\n'}$arg"
      done
    fi
  else
    # with check on integer value
    [[ -n "$PRINT_WARNING_LAG_FSEC" && -z "${PRINT_WARNING_LAG_FSEC//[0-9]/}" ]] && (( PRINT_WARNING_LAG_FSEC > 0 )) && sleep $PRINT_WARNING_LAG_FSEC

    if [[ -n "$GITHUB_ACTIONS" ]]; then
      gh_print_warnings_nobuf_nolag "$@"
    else
      gh_print_args "$@" >&2
    fi
  fi
}

function gh_write_warning_to_changelog_text_bullet_ln()
{
  (( ! ENABLE_GENERATE_CHANGELOG_FILE )) && return

  local changelog_msg="$1"

  gh_set_env_var GHWF_CHANGELOG_BUF_STR "${GHWF_CHANGELOG_BUF_STR}* warning: ${changelog_msg}"$'\r\n'
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
