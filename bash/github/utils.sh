#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
[[ -z "$BASH" || (-n "$SOURCE_GHWF_UTILS_SH" && SOURCE_GHWF_UTILS_SH -ne 0) ]] && return

SOURCE_GHWF_UTILS_SH=1 # including guard

[[ -z "$GH_WORKFLOW_ROOT" ]] && {
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
}

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?


tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/is-flag-true-in-flags-expr-string.sh"


# CAUTION:
#
#   By default assignment applies on the next GitHub Actions job step!
#
function gh_set_env_var()
{
  [[ -z "$GITHUB_ACTIONS" ]] && return 0

  local __var="$1"
  local __value="$2"

  local IFS
  local __line

  case "$__var" in
    # ignore system and builtin variables
    __* | GITHUB_* | 'IFS') ;;
    *)
      tkl_declare_global "$__var" "$__value"

      # Process line returns differently to avoid `Invalid environment variable format` error.
      #
      #   https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#setting-an-environment-variable
      #
      if [[ "${__value/[$'\r\n']/}" != "$__value" ]]; then
        echo "$__var<<::EOF::"

        IFS=$'\n'; for __line in "$__value"; do
          echo "$__line"
        done

        echo "::EOF::"
      else
        echo "$__var=$__value"
      fi
      ;;
  esac >> "$GITHUB_ENV"
}

function gh_unset_env_var()
{
  [[ -z "$GITHUB_ACTIONS" ]] && return 0

  local __var="$1"

  local IFS
  local __line

  case "$__var" in
    # ignore system and builtin variables
    __* | GITHUB_* | 'IFS') ;;
    *)
      unset "$__var"

      echo "$__var="
      ;;
  esac >> "$GITHUB_ENV"
}

function gh_update_github_env_var()
{
  [[ -z "$GITHUB_ACTIONS" ]] && return 0

  local __var="$1"

  case "$__var" in
    # ignore system and builtin variables
    __* | GITHUB_* | 'IFS') ;;
    *)
      eval "echo \"\$__var=\$$__var\""
      ;;
  esac >> "$GITHUB_ENV"
}

function gh_trim_heading_line_return_chars()
{
  local str="$1"

  while [[ "${str#[$'\r\n']}" != "$str" ]]; do
    str="${str#[$'\r\n']}"
  done

  RETURN_VALUE="$str"
}

function gh_trim_trailing_line_return_chars()
{
  local str="$1"

  while [[ "${str%[$'\r\n']}" != "$str" ]]; do
    str="${str%[$'\r\n']}"
  done

  RETURN_VALUE="$str"
}

function gh_encode_line_return_chars()
{
  local line="$1"

  RETURN_VALUE="${line//%/%25}"
  RETURN_VALUE="${RETURN_VALUE//$'\r'/%0D}"
  RETURN_VALUE="${RETURN_VALUE//$'\n'/%0A}"
}

function gh_decode_line_return_chars()
{
  local line="$1"

  RETURN_VALUE="${line//%0D/$'\r'}"
  RETURN_VALUE="${RETURN_VALUE//%0A/$'\n'}"
  RETURN_VALUE="${RETURN_VALUE//%25/%}"
}

tkl_set_return
