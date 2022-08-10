#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
[[ -z "$BASH" || (-n "$SOURCE_GHWF_PRINT_SH" && SOURCE_GHWF_PRINT_SH -ne 0) ]] && return

SOURCE_GHWF_PRINT_SH=1 # including guard

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?

tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/utils.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/print-notice.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/print-warning.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/print-error.sh"


function gh_enable_print_buffering()
{
  local enable_print_notice_buffering=${1:-0}   # by default is not buffered, printfs at first
  local enable_print_warning_buffering=${1:-1}  # by default is buffered, prints at second
  local enable_print_error_buffering=${1:-1}    # by default is buffered, prints at third

  (( enable_print_notice_buffering )) && gh_enable_print_notice_buffering
  (( enable_print_warning_buffering )) && gh_enable_print_warning_buffering
  (( enable_print_error_buffering )) && gh_enable_print_error_buffering
}

function gh_flush_print_buffers()
{
  local print_str

  # notices
  if [[ -n "${PRINT_NOTICE_BUF_STR+x}" ]]; then
    print_str="${PRINT_NOTICE_BUF_STR}"
    unset PRINT_NOTICE_BUF_STR
    gh_print_notices_nobuf_noprefix "$print_str"
  fi

  # warnings
  if [[ -n "${PRINT_WARNING_BUF_STR+x}" ]]; then
    print_str="${PRINT_WARNING_BUF_STR}"
    unset PRINT_WARNING_BUF_STR
    gh_print_warnings_nobuf_noprefix "$print_str"
  fi

  # errors
  if [[ -n "${PRINT_ERROR_BUF_STR+x}" ]]; then
    print_str="${PRINT_ERROR_BUF_STR}"
    unset PRINT_ERROR_BUF_STR
    gh_print_errors_nobuf_noprefix "$print_str"
  fi
}

function gh_write_to_changelog_text_ln()
{
  (( ! ENABLE_GENERATE_CHANGELOG_FILE )) && return

  local changelog_msg="$1"

  CHANGELOG_BUF_STR="${CHANGELOG_BUF_STR}${changelog_msg}"$'\r\n'
}

function gh_print_args()
{
  local IFS=$'\n'
  local arg

  # fix GitHub log issue when a trailing line return charcter in the message does convert into blank line

  if [[ -n "$GITHUB_ACTIONS" ]]; then
    for arg in "$@"; do
      gh_trim_trailing_line_return_chars "$arg"
      echo -n "$RETURN_VALUE" >&2 # without line return
    done
  else
    for arg in "$@"; do
      gh_trim_trailing_line_return_chars "$arg"
      echo "$RETURN_VALUE" >&2 # with line return
    done
  fi
}
