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
    # to save variables between workflow steps
    if [[ -z "${GH_ANNOTATIONS_PRINT_BUF_STR:+x}" ]]; then
      tkl_declare_global GH_ANNOTATIONS_PRINT_BUF_STR ''

      # update GitHub pipeline variables
      gh_set_env_var GH_ANNOTATIONS_PRINT_BUF_STR       "$GH_ANNOTATIONS_PRINT_BUF_STR"
    fi

    # to save variables between workflow steps
    if [[ -z "${GH_ANNOTATIONS_GROUP_ANNOT_TYPE:+x}" ]]; then
      tkl_declare_global GH_ANNOTATIONS_GROUP_ANNOT_TYPE ''
      tkl_declare_global GH_ANNOTATIONS_GROUP_ANNOT_PREFIX ''
      tkl_declare_global GH_ANNOTATIONS_GROUP_ANNOT_MSG ''
      tkl_declare_global GH_ANNOTATIONS_GROUP_ANNOT_INDEX 0

      gh_set_env_var GH_ANNOTATIONS_GROUP_ANNOT_TYPE    "$GH_ANNOTATIONS_GROUP_ANNOT_TYPE"
      gh_set_env_var GH_ANNOTATIONS_GROUP_ANNOT_PREFIX  "$GH_ANNOTATIONS_GROUP_ANNOT_PREFIX"
      gh_set_env_var GH_ANNOTATIONS_GROUP_ANNOT_MSG     "$GH_ANNOTATIONS_GROUP_ANNOT_MSG"
      gh_set_env_var GH_ANNOTATIONS_GROUP_ANNOT_INDEX   "$GH_ANNOTATIONS_GROUP_ANNOT_INDEX"
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
  local line

  # notices
  if [[ -n "${PRINT_NOTICE_BUF_STR+x}" ]]; then
    line="${PRINT_NOTICE_BUF_STR}"
    unset PRINT_NOTICE_BUF_STR
    gh_print_notices_buffer "$line"
  fi

  # warnings
  if [[ -n "${PRINT_WARNING_BUF_STR+x}" ]]; then
    line="${PRINT_WARNING_BUF_STR}"
    unset PRINT_WARNING_BUF_STR
    gh_print_warnings_buffer "$line"
  fi

  # errors
  if [[ -n "${PRINT_ERROR_BUF_STR+x}" ]]; then
    line="${PRINT_ERROR_BUF_STR}"
    unset PRINT_ERROR_BUF_STR
    gh_print_errors_buffer "$line"
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

  local annot_type="$1"         # required
  local annot_prefix="$2"
  local msg="$3"

  #gh_decode_line_return_chars "$msg"

  # stdout redirection must be issued outside
  echo "::$annot_type $annot_prefix::$msg"

  gh_process_annotation_print "$annot_type" "$annot_prefix" "$msg"

  # duplicate output into `GH_ANNOTATIONS_PRINT_BUF_STR` variable to reuse later
  GH_ANNOTATIONS_PRINT_BUF_STR="${GH_ANNOTATIONS_PRINT_BUF_STR}${GH_ANNOTATIONS_PRINT_BUF_STR:+"${RETURN_VALUES[0]}"}${RETURN_VALUES[1]}"

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

    #gh_decode_line_return_chars "$RETURN_VALUE"

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

# NOTE: Groups only annotations with the same type.
#
# CAUTION:
#
#   Because variable assignment works only between GitHub Actions job steps, then this will NOT work:
#
#     - name: head annotations
#       shell: bash
#       run: |
#         $GH_WORKFLOW_ROOT/bash/github/begin-print-annotation-group.sh notice
#         $GH_WORKFLOW_ROOT/bash/github/print-notice.sh "111" "222"
#         $GH_WORKFLOW_ROOT/bash/github/end-print-annotation-group.sh
#
#   This will work:
#
#     - name: head annotations
#       shell: bash
#       run: |
#         $GH_WORKFLOW_ROOT/bash/github/begin-print-annotation-group.sh notice
#
#     - name: head annotations
#       shell: bash
#       run: |
#         $GH_WORKFLOW_ROOT/bash/github/print-notice.sh "111" "222"
#         $GH_WORKFLOW_ROOT/bash/github/end-print-annotation-group.sh # must be last in the step
#
function gh_begin_print_annotation_group()
{
  [[ -z "$GITHUB_ACTIONS" ]] && return 0
  [[ -n "${GH_ANNOTATIONS_GROUP_ANNOT_TYPE:+x}" ]] && return 0 # ignore if previous group is not closed/ended

  local annot_type="$1"         # required
  local annot_prefix="$2"
  local msg="$3"

  [[ -z "$annot_type" ]] && return 0

  tkl_declare_global GH_ANNOTATIONS_GROUP_ANNOT_TYPE    "$annot_type"
  tkl_declare_global GH_ANNOTATIONS_GROUP_ANNOT_PREFIX  "$annot_prefix"
  tkl_declare_global GH_ANNOTATIONS_GROUP_ANNOT_MSG     "$msg"
  tkl_declare_global GH_ANNOTATIONS_GROUP_ANNOT_INDEX   0

  # update GitHub pipeline variable
  gh_set_env_var GH_ANNOTATIONS_GROUP_ANNOT_TYPE    "$GH_ANNOTATIONS_GROUP_ANNOT_TYPE"
  gh_set_env_var GH_ANNOTATIONS_GROUP_ANNOT_PREFIX  "$GH_ANNOTATIONS_GROUP_ANNOT_PREFIX"
  gh_set_env_var GH_ANNOTATIONS_GROUP_ANNOT_MSG     "$GH_ANNOTATIONS_GROUP_ANNOT_MSG"
  gh_set_env_var GH_ANNOTATIONS_GROUP_ANNOT_INDEX   "$GH_ANNOTATIONS_GROUP_ANNOT_INDEX"
}

function gh_end_print_annotation_group()
{
  [[ -z "$GITHUB_ACTIONS" ]] && return 0

  unset GH_ANNOTATIONS_GROUP_ANNOT_TYPE
  unset GH_ANNOTATIONS_GROUP_ANNOT_PREFIX
  unset GH_ANNOTATIONS_GROUP_ANNOT_MSG
  unset GH_ANNOTATIONS_GROUP_ANNOT_INDEX

  # update GitHub pipeline variable
  gh_set_env_var GH_ANNOTATIONS_GROUP_ANNOT_TYPE    "$GH_ANNOTATIONS_GROUP_ANNOT_TYPE"
  gh_set_env_var GH_ANNOTATIONS_GROUP_ANNOT_PREFIX  "$GH_ANNOTATIONS_GROUP_ANNOT_PREFIX"
  gh_set_env_var GH_ANNOTATIONS_GROUP_ANNOT_MSG     "$GH_ANNOTATIONS_GROUP_ANNOT_MSG"
  gh_set_env_var GH_ANNOTATIONS_GROUP_ANNOT_INDEX   "$GH_ANNOTATIONS_GROUP_ANNOT_INDEX"
}

# prefixes a print message with annotation data
function gh_process_annotation_print()
{
  local annot_type="$1"         # required
  local annot_prefix="$2"
  local msg="$3"

  if [[ -n "$GH_ANNOTATIONS_GROUP_ANNOT_TYPE" && "$GH_ANNOTATIONS_GROUP_ANNOT_TYPE" == "$annot_type" ]]; then
    if (( GH_ANNOTATIONS_GROUP_ANNOT_INDEX )); then
      tkl_declare_global_array RETURN_VALUES "%0A" "$msg"
    else
      tkl_declare_global_array RETURN_VALUES $'\r\n' "::$GH_ANNOTATIONS_GROUP_ANNOT_TYPE $GH_ANNOTATIONS_GROUP_ANNOT_PREFIX::${GH_ANNOTATIONS_GROUP_ANNOT_MSG}${GH_ANNOTATIONS_GROUP_ANNOT_MSG:+"%0A"}$msg"
    fi

    (( GH_ANNOTATIONS_GROUP_ANNOT_INDEX++ ))
  else
    if [[ -n "$GH_ANNOTATIONS_GROUP_ANNOT_TYPE" ]]; then
      # reset index only to group next prints
      GH_ANNOTATIONS_GROUP_ANNOT_INDEX=0
    fi

    tkl_declare_global_array RETURN_VALUES $'\r\n' "::$annot_type $annot_prefix::$msg"
  fi

  if [[ -n "$GH_ANNOTATIONS_GROUP_ANNOT_TYPE" ]]; then
    # update GitHub pipeline variable
    gh_set_env_var GH_ANNOTATIONS_GROUP_ANNOT_INDEX   "$GH_ANNOTATIONS_GROUP_ANNOT_INDEX"
  fi
}

tkl_set_return
