#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
[[ -z "$BASH" || (-n "$SOURCE_GHWF_GITHUB_UTILS_SH" && SOURCE_GHWF_GITHUB_UTILS_SH -ne 0) ]] && return

SOURCE_GHWF_GITHUB_UTILS_SH=1 # including guard

if [[ -z "$GH_WORKFLOW_ROOT" ]]; then
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
fi

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?


tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/_common/utils.sh"
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

tkl_set_return
