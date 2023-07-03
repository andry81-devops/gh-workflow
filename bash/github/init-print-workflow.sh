#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
[[ -z "$BASH" || (-n "$SOURCE_GHWF_INIT_PRINT_WORKFLOW_SH" && SOURCE_GHWF_INIT_PRINT_WORKFLOW_SH -ne 0) ]] && return

SOURCE_GHWF_INIT_PRINT_WORKFLOW_SH=1 # including guard

if [[ -z "$GH_WORKFLOW_ROOT" ]]; then
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
fi

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
    if [[ -z "${GHWF_ANNOTATIONS_PRINT_BUF_STR:+x}" ]]; then
      gh_set_env_var GHWF_ANNOTATIONS_PRINT_BUF_STR ''
    fi

    # to save variables between workflow steps
    if [[ -z "${GHWF_ANNOTATIONS_GROUP_ANNOT_TYPE:+x}" ]]; then
      gh_set_env_var GHWF_ANNOTATIONS_GROUP_ANNOT_TYPE    ''
      gh_set_env_var GHWF_ANNOTATIONS_GROUP_ANNOT_PREFIX  ''
      gh_set_env_var GHWF_ANNOTATIONS_GROUP_ANNOT_MSG     ''
      gh_set_env_var GHWF_ANNOTATIONS_GROUP_ANNOT_INDEX   0
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
  if [[ -n "${GHWF_PRINT_NOTICE_BUF_STR+x}" ]]; then
    line="${GHWF_PRINT_NOTICE_BUF_STR}"
    gh_unset_env_var GHWF_PRINT_NOTICE_BUF_STR
    gh_print_notices_buffer "$line"
  fi

  # warnings
  if [[ -n "${GHWF_PRINT_WARNING_BUF_STR+x}" ]]; then
    line="${GHWF_PRINT_WARNING_BUF_STR}"
    gh_unset_env_var GHWF_PRINT_WARNING_BUF_STR
    gh_print_warnings_buffer "$line"
  fi

  # errors
  if [[ -n "${GHWF_PRINT_ERROR_BUF_STR+x}" ]]; then
    line="${GHWF_PRINT_ERROR_BUF_STR}"
    gh_unset_env_var GHWF_PRINT_ERROR_BUF_STR
    gh_print_errors_buffer "$line"
  fi
}

function gh_write_to_changelog_text_ln()
{
  gh_write_to_changelog_named_text_ln '' '' "$@"
}

function gh_write_to_changelog_named_text_ln()
{
  (( ! ENABLE_GENERATE_CHANGELOG_FILE )) && return

  local changelog_msg_name_to_insert_from="$1"
  local changelog_msg_name="$2"
  local changelog_msg="$3"

  if (( ENABLE_CHANGELOG_BUF_ARR_AUTO_SERIALIZE )); then
    tkl_deserialize_array "$GHWF_CHANGELOG_BUF_KEY_SERIALIZED_ARR_STR" GHWF_CHANGELOG_BUF_KEY_ARR
    tkl_deserialize_array "$GHWF_CHANGELOG_BUF_VALUE_SERIALIZED_ARR_STR" GHWF_CHANGELOG_BUF_VALUE_ARR
  fi

  gh_find_changelog_buf_arr_index_to_insert_from "$changelog_msg_name_to_insert_from"

  GHWF_CHANGELOG_BUF_KEY_ARR=("${GHWF_CHANGELOG_BUF_KEY_ARR[@]:0:RETURN_VALUE}" "$changelog_msg_name" "${GHWF_CHANGELOG_BUF_KEY_ARR[@]:RETURN_VALUE}")
  GHWF_CHANGELOG_BUF_VALUE_ARR=("${GHWF_CHANGELOG_BUF_VALUE_ARR[@]:0:RETURN_VALUE}" "$changelog_msg"$'\r\n' "${GHWF_CHANGELOG_BUF_VALUE_ARR[@]:RETURN_VALUE}")

  if (( ENABLE_CHANGELOG_BUF_ARR_AUTO_SERIALIZE )); then
    tkl_serialize_array GHWF_CHANGELOG_BUF_KEY_ARR GHWF_CHANGELOG_BUF_KEY_SERIALIZED_ARR_STR
    tkl_serialize_array GHWF_CHANGELOG_BUF_VALUE_ARR GHWF_CHANGELOG_BUF_VALUE_SERIALIZED_ARR_STR

    gh_set_env_var GHWF_CHANGELOG_BUF_KEY_SERIALIZED_ARR_STR "$GHWF_CHANGELOG_BUF_KEY_SERIALIZED_ARR_STR"
    gh_set_env_var GHWF_CHANGELOG_BUF_VALUE_SERIALIZED_ARR_STR "$GHWF_CHANGELOG_BUF_VALUE_SERIALIZED_ARR_STR"
  fi
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

  # NOTE:
  #   The stdout redirection must be issued outside.
  #
  echo "::$annot_type $annot_prefix::$msg"

  gh_process_annotation_print "$annot_type" "$annot_prefix" "$msg"

  # duplicate output into `GHWF_ANNOTATIONS_PRINT_BUF_STR` variable to reuse later
  gh_set_env_var GHWF_ANNOTATIONS_PRINT_BUF_STR "${GHWF_ANNOTATIONS_PRINT_BUF_STR}${GHWF_ANNOTATIONS_PRINT_BUF_STR:+"${RETURN_VALUES[0]}"}${RETURN_VALUES[1]}"
}

function gh_print_annotation_line()
{
  [[ -z "$GITHUB_ACTIONS" ]] && return 0

  local line="$1"

  #gh_decode_line_return_chars "$msg"

  # NOTE:
  #   The stdout redirection must be issued outside.
  #
  echo "$line"

  # duplicate output into `GHWF_ANNOTATIONS_PRINT_BUF_STR` variable to reuse later
  gh_set_env_var GHWF_ANNOTATIONS_PRINT_BUF_STR "${GHWF_ANNOTATIONS_PRINT_BUF_STR}${GHWF_ANNOTATIONS_PRINT_BUF_STR:+$'\r\n'}$line"
}

function gh_flush_print_annotations()
{
  local IFS
  local empty
  local annot_type
  local line

  [[ -z "$GITHUB_ACTIONS" ]] && return 0

  IFS=$'\n'; for line in "$GHWF_ANNOTATIONS_PRINT_BUF_STR"; do
    gh_trim_trailing_line_return_chars "$line"

    # gh_decode_line_return_chars "$RETURN_VALUE"

    IFS=':' read -r empty empty annot_type <<< "$RETURN_VALUE"
    IFS=$'\t ' read -r annot_type empty <<< "$annot_type"

    case "$annot_type" in
      'notice') echo "$RETURN_VALUE";;
      *) echo "$RETURN_VALUE" >&2;;
    esac
  done

  gh_unset_env_var GHWF_ANNOTATIONS_PRINT_BUF_STR
}

# NOTE: Groups only annotations with the same type.
#

# NOTE:
#
#   Basically variable assignment works only between GitHub Actions job steps.
#   But the `init-basic-workflow.sh` script does reload the `GITHUB_ENV` file
#   implicitly, so that must work even if executed from a child process:
#
#     - name: head annotations
#       shell: bash
#       run: |
#         $GH_WORKFLOW_ROOT/bash/github/begin-print-annotation-group.sh notice
#         $GH_WORKFLOW_ROOT/bash/github/print-notice.sh "111" "222"
#         $GH_WORKFLOW_ROOT/bash/github/end-print-annotation-group.sh # must be last in the step
#

function gh_begin_print_annotation_group()
{
  [[ -z "$GITHUB_ACTIONS" ]] && return 0
  [[ -n "${GHWF_ANNOTATIONS_GROUP_ANNOT_TYPE:+x}" ]] && return 0 # ignore if previous group is not closed/ended

  local annot_type="$1"         # required
  local annot_prefix="$2"
  local msg="$3"

  [[ -z "$annot_type" ]] && return 0

  gh_set_env_var GHWF_ANNOTATIONS_GROUP_ANNOT_TYPE    "$annot_type"
  gh_set_env_var GHWF_ANNOTATIONS_GROUP_ANNOT_PREFIX  "$annot_prefix"
  gh_set_env_var GHWF_ANNOTATIONS_GROUP_ANNOT_MSG     "$msg"
  gh_set_env_var GHWF_ANNOTATIONS_GROUP_ANNOT_INDEX   0
}

function gh_end_print_annotation_group()
{
  [[ -z "$GITHUB_ACTIONS" ]] && return 0

  gh_unset_env_var GHWF_ANNOTATIONS_GROUP_ANNOT_TYPE
  gh_unset_env_var GHWF_ANNOTATIONS_GROUP_ANNOT_PREFIX
  gh_unset_env_var GHWF_ANNOTATIONS_GROUP_ANNOT_MSG
  gh_unset_env_var GHWF_ANNOTATIONS_GROUP_ANNOT_INDEX
}

# prefixes a print message with annotation data
function gh_process_annotation_print()
{
  local annot_type="$1"         # required
  local annot_prefix="$2"
  local msg="$3"

  if [[ -n "$GHWF_ANNOTATIONS_GROUP_ANNOT_TYPE" && "$GHWF_ANNOTATIONS_GROUP_ANNOT_TYPE" == "$annot_type" ]]; then
    if (( GHWF_ANNOTATIONS_GROUP_ANNOT_INDEX )); then
      tkl_declare_global_array RETURN_VALUES "%0D%0A" "$msg"
    else
      tkl_declare_global_array RETURN_VALUES $'\r\n' "::$GHWF_ANNOTATIONS_GROUP_ANNOT_TYPE $GHWF_ANNOTATIONS_GROUP_ANNOT_PREFIX::${GHWF_ANNOTATIONS_GROUP_ANNOT_MSG}${GHWF_ANNOTATIONS_GROUP_ANNOT_MSG:+"%0D%0A"}$msg"
    fi

    (( GHWF_ANNOTATIONS_GROUP_ANNOT_INDEX++ ))

    gh_update_github_env_var GHWF_ANNOTATIONS_GROUP_ANNOT_INDEX
  else
    if [[ -n "$GHWF_ANNOTATIONS_GROUP_ANNOT_TYPE" ]]; then
      gh_set_env_var GHWF_ANNOTATIONS_GROUP_ANNOT_INDEX 0
    fi

    tkl_declare_global_array RETURN_VALUES $'\r\n' "::$annot_type $annot_prefix::$msg"
  fi
}

tkl_set_return
