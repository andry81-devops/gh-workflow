#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
[[ -z "$BASH" || (-n "$SOURCE_GHWF_PRINT_NOTICE_SH" && SOURCE_GHWF_PRINT_NOTICE_SH -ne 0) ]] && return

SOURCE_GHWF_PRINT_NOTICE_SH=1 # including guard

if [[ -z "$GH_WORKFLOW_ROOT" ]]; then
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
fi

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?

tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-print-workflow.sh"


function gh_enable_print_notice_buffering()
{
  if [[ -z "${GHWF_PRINT_NOTICE_BUF_STR+x}" ]]; then
    gh_set_env_var GHWF_PRINT_NOTICE_BUF_STR ''
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

  if [[ -n "${GHWF_PRINT_NOTICE_BUF_STR+x}" ]]; then
    if [[ -n "$GITHUB_ACTIONS" ]]; then
      for arg in "$@"; do
        line="${line}${line:+$'\r\n'}$arg"
      done

      gh_trim_trailing_line_return_chars "$line"

      # fix multiline text in a single argument
      gh_encode_line_return_chars "$RETURN_VALUE"

      gh_process_annotation_print notice '' "$RETURN_VALUE"

      gh_set_env_var GHWF_PRINT_NOTICE_BUF_STR "${GHWF_PRINT_NOTICE_BUF_STR}${GHWF_PRINT_NOTICE_BUF_STR:+"${RETURN_VALUES[0]}"}${RETURN_VALUES[1]}"
    else
      gh_set_env_var GHWF_PRINT_NOTICE_BUF_STR "${GHWF_PRINT_NOTICE_BUF_STR}${GHWF_PRINT_NOTICE_BUF_STR:+$'\r\n'}$*"
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
    for arg in "$@"; do
      line="${line}${line:+$'\r\n'}$arg"
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
  local arg

  # fix GitHub log issue when a trailing line return charcter in the message does convert into blank line

  if [[ -n "$GITHUB_ACTIONS" ]]; then
    for arg in "$@"; do
      gh_trim_trailing_line_return_chars "$arg"

      # fix multiline text in a single argument
      gh_encode_line_return_chars "$RETURN_VALUE"

      gh_print_annotation notice '' "$RETURN_VALUE"
    done
  else
    for arg in "$@"; do
      gh_trim_trailing_line_return_chars "$arg"

      echo "$RETURN_VALUE"
    done
  fi
}

function gh_print_notices_buffer()
{
  local buf="$1"

  [[ -z "$buf" ]] && return 0

  local IFS
  local line

  # with check on integer value
  [[ -n "$PRINT_NOTICE_LAG_FSEC" && -z "${PRINT_NOTICE_LAG_FSEC//[0-9]/}" ]] && (( PRINT_NOTICE_LAG_FSEC > 0 )) && sleep $PRINT_NOTICE_LAG_FSEC

  if [[ -n "$GITHUB_ACTIONS" ]]; then
    while IFS=$'\n' read -r line; do
      gh_trim_trailing_line_return_chars "$line"

      # fix multiline text in a single argument
      gh_encode_line_return_chars "$RETURN_VALUE"

      gh_print_annotation_line "$RETURN_VALUE"
    done <<< "$buf"
  else
    while IFS=$'\n' read -r line; do
      gh_print_args "$line"
    done <<< "$buf"
  fi
}

function gh_print_notices()
{
  local arg

  if [[ -n "${GHWF_PRINT_NOTICE_BUF_STR+x}" ]]; then
    if [[ -n "$GITHUB_ACTIONS" ]]; then
      for arg in "$@"; do
        gh_trim_trailing_line_return_chars "$arg"

        # fix multiline text in a single argument
        gh_encode_line_return_chars "$RETURN_VALUE"

        gh_process_annotation_print notice '' "$RETURN_VALUE"

        gh_set_env_var GHWF_PRINT_NOTICE_BUF_STR "${GHWF_PRINT_NOTICE_BUF_STR}${GHWF_PRINT_NOTICE_BUF_STR:+"${RETURN_VALUES[0]}"}${RETURN_VALUES[1]}"
      done
    else
      for arg in "$@"; do
        gh_set_env_var GHWF_PRINT_NOTICE_BUF_STR "${GHWF_PRINT_NOTICE_BUF_STR}${GHWF_PRINT_NOTICE_BUF_STR:+$'\r\n'}$arg"
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
  gh_write_notice_to_changelog_named_text_bullet_ln '' '' "$@"
}

function gh_write_notice_to_changelog_named_text_bullet_ln()
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
  GHWF_CHANGELOG_BUF_VALUE_ARR=("${GHWF_CHANGELOG_BUF_VALUE_ARR[@]:0:RETURN_VALUE}" "* notice: $changelog_msg" "${GHWF_CHANGELOG_BUF_VALUE_ARR[@]:RETURN_VALUE}")

  if (( ENABLE_CHANGELOG_BUF_ARR_AUTO_SERIALIZE )); then
    tkl_serialize_array GHWF_CHANGELOG_BUF_KEY_ARR GHWF_CHANGELOG_BUF_KEY_SERIALIZED_ARR_STR
    tkl_serialize_array GHWF_CHANGELOG_BUF_VALUE_ARR GHWF_CHANGELOG_BUF_VALUE_SERIALIZED_ARR_STR

    gh_set_env_var GHWF_CHANGELOG_BUF_KEY_SERIALIZED_ARR_STR "$GHWF_CHANGELOG_BUF_KEY_SERIALIZED_ARR_STR"
    gh_set_env_var GHWF_CHANGELOG_BUF_VALUE_SERIALIZED_ARR_STR "$GHWF_CHANGELOG_BUF_VALUE_SERIALIZED_ARR_STR"
  fi
}

# format: <message> | <message> <changelog_message>
function gh_print_notice_and_write_to_changelog_text_ln()
{
  gh_print_notice_and_write_to_changelog_named_text_ln '' '' "$@"
}

# format: <message_name> <message> | <message_name> <message> <changelog_message>
function gh_print_notice_and_write_to_changelog_named_text_ln()
{
  local notice_msg_name_to_insert_from="$1"
  local notice_msg_name="$2"
  local notice_msg="$3"

  gh_print_notice_ln "$notice_msg"

  if (( ENABLE_GENERATE_CHANGELOG_FILE )); then
    local changelog_msg="$4"

    (( ${#@} < 4 )) && changelog_msg="$notice_msg"

    gh_write_to_changelog_named_text_ln "$notice_msg_name_to_insert_from" "$notice_msg_name" "$changelog_msg"
  fi
}

# format: <message> | <message> <changelog_message>
function gh_print_notice_and_write_to_changelog_text_bullet_ln()
{
  gh_print_notice_and_write_to_changelog_named_text_bullet_ln '' '' "$@"
}

# format: <message_name> <message> | <message_name> <message> <changelog_message>
function gh_print_notice_and_write_to_changelog_named_text_bullet_ln()
{
  local notice_msg_name_to_insert_from="$1"
  local notice_msg_name="$2"
  local notice_msg="$3"

  gh_print_notice_ln "$notice_msg"

  if (( ENABLE_GENERATE_CHANGELOG_FILE )); then
    local changelog_msg="$4"

    (( ${#@} < 4 )) && changelog_msg="$notice_msg"

    gh_write_notice_to_changelog_named_text_bullet_ln "$notice_msg_name_to_insert_from" "$notice_msg_name" "$changelog_msg"
  fi
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  gh_print_notices "$@"
fi
