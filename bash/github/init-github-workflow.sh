#!/usr/bin/env bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
[[ -n "$BASH" ]] || return 0 || exit 0 # exit to avoid continue if the return can not be called

# check inclusion guard if script is included
[[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]] || (( ! SOURCE_GHWF_INIT_GITHUB_WORKFLOW_SH )) || return 0 || exit 0 # exit to avoid continue if the return can not be called

SOURCE_GHWF_INIT_GITHUB_WORKFLOW_SH=1 # including guard

if [[ -z "$GH_WORKFLOW_ROOT" ]]; then
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
fi

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?

tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-basic-workflow.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/utils.sh"


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

  local __line
  local __line_no_cr
  local __empty
  local __prefix
  local __var
  local __value
  local __value_no_cr
  local __eof
  local __read_var=0

  local IFS

  while IFS=$'\n' read -r __line; do
    __line_no_cr="${__line%$'\r'}" # trim last CR

    if [[ -z "$__line_no_cr" ]]; then
      continue
    fi

    if (( ! __read_var )); then
      IFS='<' read -r __var __empty __eof <<< "$__line_no_cr"
      if [[ -z "$__eof" ]]; then
        IFS='=' read -r __var __value_no_cr <<< "$__line_no_cr"

        case "$__var" in
          # ignore system and builtin variables
          __* | GITHUB_* | 'IFS') ;;
          *)tkl_declare_global "$__var" "$__value_no_cr" ;;
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
    elif [[ "$__line_no_cr" != "$__eof" ]]; then
      __value="$__value${__value:+$'\r\n'}$__line_no_cr"
    else
      tkl_declare_global "$__var" "$__value"
      __read_var=0
    fi
  done < "$__vars_file"
}

# CAUTION:
#   You must always load unconditionally all the `GITHUB_ENV` variables!
#
#   The reason is in the method of the bash script execution inside a
#   GitHub Action step. While the GitHub Action loads the `GITHUB_ENV`
#   variables only in the next step, the variables can be already dropped in
#   the current step.
#
#   If a bash script inside GitHub Action step does not have a shebang line,
#   then each line of it does run as a bash subprocess. This means that the
#   all variables would be dropped after a subprocess exit. This function
#   reloads the `GITHUB_ENV` on each such subprocess execution.
#
function gh_eval_github_env()
{
  [[ -n "$GITHUB_ACTIONS" ]] || return 0

  gh_eval_github_env_file "$GITHUB_ENV"
}

tkl_set_return
