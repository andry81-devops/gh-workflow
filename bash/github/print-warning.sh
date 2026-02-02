#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
[[ -n "$BASH" ]] || return 0 || exit 0 # exit to avoid continue if the return can not be called

# check inclusion guard if script is included
[[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]] || (( ! SOURCE_GHWF_PRINT_WARNING_SH )) || return 0 || exit 0 # exit to avoid continue if the return can not be called

SOURCE_GHWF_PRINT_WARNING_SH=1 # including guard

if [[ -z "$GH_WORKFLOW_ROOT" ]]; then
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
fi

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?

tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-print-workflow.sh"


function gh_enable_print_warning_buffering()
{
  if [[ -z "${GHWF_PRINT_WARNING_BUF_STR+x}" ]]; then
    gh_set_env_var GHWF_PRINT_WARNING_BUF_STR '' # sets to empty to show the variable is initialized
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
      for arg in "$@"; do
        line="${line}${line:+$'\r\n'}$arg"
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
    if [[ -n "$PRINT_WARNING_LAG_FSEC" && -z "${PRINT_WARNING_LAG_FSEC//[0-9]/}" ]] && (( PRINT_WARNING_LAG_FSEC > 0 )); then
      sleep $PRINT_WARNING_LAG_FSEC
    fi

    gh_print_warning_ln_nobuf_nolag "$@"
  fi
}

function gh_print_warning_ln_nobuf_nolag()
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

    gh_print_annotation warning '' "$RETURN_VALUE" >&2
  else
    gh_trim_trailing_line_return_chars "$*"

    echo "$RETURN_VALUE" >&2
  fi
}

function gh_print_warnings_nobuf_nolag()
{
  local arg

  # fix GitHub log issue when a trailing line return charcter in the message does convert into blank line

  if [[ -n "$GITHUB_ACTIONS" ]]; then
    for arg in "$@"; do
      gh_trim_trailing_line_return_chars "$arg"

      # fix multiline text in a single argument
      gh_encode_line_return_chars "$RETURN_VALUE"

      gh_print_annotation warning '' "$RETURN_VALUE"
    done >&2
  else
    for arg in "$@"; do
      gh_trim_trailing_line_return_chars "$arg"

      echo "$RETURN_VALUE"
    done >&2
  fi
}

function gh_print_warnings_buffer()
{
  local buf="$1"

  [[ -n "$buf" ]] || return 0

  local line

  local IFS

  # with check on integer value
  if [[ -n "$PRINT_WARNING_LAG_FSEC" && -z "${PRINT_WARNING_LAG_FSEC//[0-9]/}" ]] && (( PRINT_WARNING_LAG_FSEC > 0 )); then
    sleep $PRINT_WARNING_LAG_FSEC
  fi

  if [[ -n "$GITHUB_ACTIONS" ]]; then
    while IFS=$'\n' read -r line; do
      gh_trim_trailing_line_return_chars "$line"

      # fix multiline text in a single argument
      gh_encode_line_return_chars "$RETURN_VALUE"

      gh_print_annotation_line "$RETURN_VALUE"
    done <<< "$buf" >&2
  else
    while IFS=$'\n' read -r line; do
      gh_print_args "$line"
    done <<< "$buf" >&2
  fi
}

function gh_print_warnings()
{
  local arg

  if [[ -n "${GHWF_PRINT_WARNING_BUF_STR+x}" ]]; then
    if [[ -n "$GITHUB_ACTIONS" ]]; then
      for arg in "$@"; do
        gh_trim_trailing_line_return_chars "$arg"

        # fix multiline text in a single argument
        gh_encode_line_return_chars "$RETURN_VALUE"

        gh_process_annotation_print warning '' "$RETURN_VALUE"

        gh_set_env_var  GHWF_PRINT_WARNING_BUF_STR "${GHWF_PRINT_WARNING_BUF_STR}${GHWF_PRINT_WARNING_BUF_STR:+"${RETURN_VALUES[0]}"}${RETURN_VALUES[1]}"
      done
    else
      for arg in "$@"; do
        gh_set_env_var GHWF_PRINT_WARNING_BUF_STR "${GHWF_PRINT_WARNING_BUF_STR}${GHWF_PRINT_WARNING_BUF_STR:+$'\r\n'}$arg"
      done
    fi
  else
    # with check on integer value
    if [[ -n "$PRINT_WARNING_LAG_FSEC" && -z "${PRINT_WARNING_LAG_FSEC//[0-9]/}" ]] && (( PRINT_WARNING_LAG_FSEC > 0 )); then
      sleep $PRINT_WARNING_LAG_FSEC
    fi

    if [[ -n "$GITHUB_ACTIONS" ]]; then
      gh_print_warnings_nobuf_nolag "$@"
    else
      gh_print_args "$@" >&2
    fi
  fi
}

function gh_write_warning_to_changelog_text_bullet_ln()
{
  gh_write_warning_to_changelog_named_text_bullet_ln '' '' "$@"
}

function gh_write_warning_to_changelog_named_text_bullet_ln()
{
  (( ENABLE_GENERATE_CHANGELOG_FILE )) || return

  local changelog_msg_name_to_insert_from="$1"
  local changelog_msg_name="$2"
  local changelog_msg="$3"

  if (( ENABLE_CHANGELOG_BUF_ARR_AUTO_SERIALIZE )); then
    tkl_deserialize_array "$GHWF_CHANGELOG_BUF_KEY_SERIALIZED_ARR_STR" GHWF_CHANGELOG_BUF_KEY_ARR
    tkl_deserialize_array "$GHWF_CHANGELOG_BUF_VALUE_SERIALIZED_ARR_STR" GHWF_CHANGELOG_BUF_VALUE_ARR
  fi

  gh_find_changelog_buf_arr_index_to_insert_from "$changelog_msg_name_to_insert_from"

  GHWF_CHANGELOG_BUF_KEY_ARR=("${GHWF_CHANGELOG_BUF_KEY_ARR[@]:0:RETURN_VALUE}" "$changelog_msg_name" "${GHWF_CHANGELOG_BUF_KEY_ARR[@]:RETURN_VALUE}")
  GHWF_CHANGELOG_BUF_VALUE_ARR=("${GHWF_CHANGELOG_BUF_VALUE_ARR[@]:0:RETURN_VALUE}" "* warning: $changelog_msg" "${GHWF_CHANGELOG_BUF_VALUE_ARR[@]:RETURN_VALUE}")

  if (( ENABLE_CHANGELOG_BUF_ARR_AUTO_SERIALIZE )); then
    tkl_serialize_array GHWF_CHANGELOG_BUF_KEY_ARR GHWF_CHANGELOG_BUF_KEY_SERIALIZED_ARR_STR
    tkl_serialize_array GHWF_CHANGELOG_BUF_VALUE_ARR GHWF_CHANGELOG_BUF_VALUE_SERIALIZED_ARR_STR

    gh_set_env_var GHWF_CHANGELOG_BUF_KEY_SERIALIZED_ARR_STR "$GHWF_CHANGELOG_BUF_KEY_SERIALIZED_ARR_STR"
    gh_set_env_var GHWF_CHANGELOG_BUF_VALUE_SERIALIZED_ARR_STR "$GHWF_CHANGELOG_BUF_VALUE_SERIALIZED_ARR_STR"
  fi
}

# format: <message> | <message> <changelog_message>
function gh_print_warning_and_write_to_changelog_text_ln()
{
  gh_print_warning_and_write_to_changelog_named_text_ln '' '' "$@"
}

# format: <message_name> <message> | <message_name> <message> <changelog_message>
function gh_print_warning_and_write_to_changelog_named_text_ln()
{
  local warning_msg_name_to_insert_from="$1"
  local warning_msg_name="$2"
  local warning_msg="$3"

  gh_print_warning_ln "$warning_msg"

  if (( ENABLE_GENERATE_CHANGELOG_FILE )); then
    local changelog_msg="$4"

    if (( ${#@} < 4 )); then
      changelog_msg="$warning_msg"
    fi

    gh_write_to_changelog_named_text_ln "$warning_msg_name_to_insert_from" "$warning_msg_name" "$changelog_msg"
  fi
}

# format: <message> | <message> <changelog_message>
function gh_print_warning_and_write_to_changelog_text_bullet_ln()
{
  gh_print_warning_and_write_to_changelog_named_text_bullet_ln '' '' "$@"
}

# format: <message_name> <message> | <message_name> <message> <changelog_message>
function gh_print_warning_and_write_to_changelog_named_text_bullet_ln()
{
  local warning_msg_name_to_insert_from="$1"
  local warning_msg_name="$2"
  local warning_msg="$3"

  gh_print_warning_ln "$warning_msg"

  if (( ENABLE_GENERATE_CHANGELOG_FILE )); then
    local changelog_msg="$4"

    if (( ${#@} < 4 )); then
      changelog_msg="$warning_msg"
    fi

    gh_write_warning_to_changelog_named_text_bullet_ln "$warning_msg_name_to_insert_from" "$warning_msg_name" "$changelog_msg"
  fi
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  tkl_get_include_nest_level && tkl_execute_calls gh # execute init functions only after the last include

  gh_print_warnings "$@"
fi
