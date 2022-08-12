#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
[[ -z "$BASH" || (-n "$SOURCE_GHWF_INIT_PRINT_WORKFLOW_SH" && SOURCE_GHWF_INIT_PRINT_WORKFLOW_SH -ne 0) ]] && return

SOURCE_GHWF_INIT_PRINT_WORKFLOW_SH=1 # including guard

[[ -z "$GH_WORKFLOW_ROOT" ]] && {
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
}

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?

tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-basic-workflow.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/utils.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/print-notice.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/print-warning.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/print-error.sh"


function init_print_workflow()
{
  gh_set_print_warning_lag  .025 # 25 msec
  gh_set_print_error_lag    .025

  if [[ -n "$GITHUB_ACTIONS" ]]; then
    if [[ -z "${GH_ANNOTATIONS_PRINT_BUF_STR:+x}" ]]; then # to save buffer between workflow steps
      tkl_declare_global GH_ANNOTATIONS_PRINT_BUF_STR ''

      # update GitHub pipeline variable
      gh_set_env_var GH_ANNOTATIONS_PRINT_BUF_STR "$GH_ANNOTATIONS_PRINT_BUF_STR"
    fi
  fi

  return 0
}

init_print_workflow || exit $?


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

  # update GitHub pipeline variable
  gh_set_env_var CHANGELOG_BUF_STR "$CHANGELOG_BUF_STR"
}

function gh_print_args()
{
  local IFS
  local arg
  local RETURN_VALUE

  IFS=$'\n'; for arg in "$@"; do
    gh_trim_trailing_line_return_chars "$arg"
    echo "$RETURN_VALUE"
  done
}

# always buffered, needs to call `gh_flush_print_annotations` to execute all prints
function gh_print_annotation()
{
  [[ -z "$GITHUB_ACTIONS" ]] && return 0

  local annot_type="$1"
  local annot_line="$2"

  echo "::$annot_type $annot_line"

  # duplicate output into `GH_ANNOTATIONS_PRINT_BUF_STR` variable to reuse later
  GH_ANNOTATIONS_PRINT_BUF_STR="${GH_ANNOTATIONS_PRINT_BUF_STR}${GH_ANNOTATIONS_PRINT_BUF_STR:+$'\r\n'}::$annot_type $annot_line"

  # update GitHub pipeline variable
  gh_set_env_var GH_ANNOTATIONS_PRINT_BUF_STR "$GH_ANNOTATIONS_PRINT_BUF_STR"
}

function gh_flush_print_annotations()
{
  local IFS
  local empty
  local annot_type
  local line

  [[ -z "$GITHUB_ACTIONS" ]] && return 0

  IFS=$'\n'; for line in "$GH_ANNOTATIONS_PRINT_BUF_STR"; do
    gh_trim_trailing_line_return_chars "$line"

    IFS=':' read -r empty empty annot_type <<< "$RETURN_VALUE"
    IFS=$'\t ' read -r annot_type empty <<< "$annot_type"

    case "$annot_type" in
      'notice') echo "$RETURN_VALUE";;
      *) echo "$RETURN_VALUE" >&2;;
    esac
  done

  unset GH_ANNOTATIONS_PRINT_BUF_STR

  # update GitHub pipeline variable
  gh_set_env_var GH_ANNOTATIONS_PRINT_BUF_STR "$GH_ANNOTATIONS_PRINT_BUF_STR"
}

tkl_set_return
