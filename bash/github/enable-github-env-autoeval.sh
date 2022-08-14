#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
[[ -z "$BASH" || (-n "$SOURCE_GHWF_ENABLE_GITHUB_ENV_AUTOEVAL_SH" && SOURCE_GHWF_ENABLE_GITHUB_ENV_AUTOEVAL_SH -ne 0) ]] && return

SOURCE_GHWF_ENABLE_GITHUB_ENV_AUTOEVAL_SH=1 # including guard

[[ -z "$GH_WORKFLOW_ROOT" ]] && {
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
}

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?

tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/utils.sh"


function gh_enable_github_auto_eval()
{
  [[ -z "$GITHUB_ACTIONS" ]] && return 0

  if [[ -z "${GHWF_GITHUB_ENV_AUTOEVAL:+x}" ]]; then # to save veriable between workflow steps
    gh_set_env_var GHWF_GITHUB_ENV_AUTOEVAL  1
  fi
}

function gh_disable_github_auto_eval()
{
  [[ -z "$GITHUB_ACTIONS" ]] && return 0

  gh_unset_env_var GHWF_GITHUB_ENV_AUTOEVAL
}

# Reads and evaluates `GITHUB_ENV` file to setup environment variables immediately
# and avoids wait for the next GitHub Actions job step to use them.
#
# CAUTION:
#   The function can has differences with the internal load logic and so can
#   has incorrect or deviated results.
#
function gh_eval_github_env_file()
{
  local __vars_file="$1"

  local IFS
  local __line
  local __line_filtered
  local __empty
  local __prefix
  local __var
  local __value
  local __eof
  local __read_var=0

  while IFS=$'\r\n' read -r __line; do
    if [[ -z "$__line" ]]; then
      continue
    fi

    gh_trim_trailing_line_return_chars "$__line"

    __line_filtered="$RETURN_VALUE"

    if (( ! __read_var )); then
      IFS='<' read -r __var __empty __eof <<< "$__line_filtered"
      if [[ -z "$__eof" ]]; then
        IFS='=' read -r __var empty <<< "$__line_filtered"
        IFS='=' read -r empty __value <<< "$__line"

        case "$__var" in
          # ignore system and builtin variables
          __* | GITHUB_* | 'IFS') ;;
          *) tkl_declare_global "$__var" "$__value" ;;
        esac
      else
        case "$__var" in
          # ignore system and builtin variables
          __* | GITHUB_* | 'IFS') ;;
          *)
            __read_var=1
            __value=''
            ;;
        esac
      fi
    elif [[ "$__line_filtered" != "$__eof" ]]; then
      __value="$__value$__line"$'\n'
    else
      tkl_declare_global "$__var" "$__value"
      __read_var=0
    fi
  done < "$__vars_file"
}

function gh_eval_github_env()
{
  [[ -z "$GITHUB_ACTIONS" ]] && return 0

  gh_eval_github_env_file "$GITHUB_ENV"
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  gh_enable_github_auto_eval "$@"
fi
