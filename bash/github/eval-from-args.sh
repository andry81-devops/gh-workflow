#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
[[ -n "$BASH" ]] || return 0 || exit 0 # exit to avoid continue if the return can not be called

# check inclusion guard if script is included
[[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]] || (( ! SOURCE_GHWF_EVAL_FROM_ARGS_SH )) || return 0 || exit 0 # exit to avoid continue if the return can not be called

SOURCE_GHWF_EVAL_FROM_ARGS_SH=1 # including guard

if [[ -z "$GH_WORKFLOW_ROOT" ]]; then
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
fi

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?

tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-github-workflow.sh"


function gh_eval_from_args()
{
  local flag_args=()

  tkl_read_command_line_flags flag_args "$@"
  (( ! ${#flag_args[@]} )) || shift ${#flag_args[@]}

  local flag_eval_github_env=0
  local flag_print_cmdline=0

  local flag
  for flag in "${flag_args[@]}"; do
    if [[ "${flag[1]}" != '-' ]]; then
      [[ "${flag/p/}" == "$flag" ]] || flag_print_cmdline=1
      [[ "${flag/E/}" == "$flag" ]] || flag_eval_github_env=1
    else
      [[ "$flag" != "--print_cmdline" ]] || flag_print_cmdline=1
      [[ "$flag" != "--eval_github_env" ]] || flag_eval_github_env=1
    fi
  done

  unset flag
  unset flag_args

  if (( flag_print_cmdline )); then
    unset flag_print_cmdline
    if (( flag_eval_github_env )); then
      unset flag_eval_github_env

      gh_eval_github_env
    fi

    while (( ${#@} )); do
      echo ">$1"
      eval "$1" || return $? # interrupt loop on error
      shift
    done
  else
    unset flag_print_cmdline
    if (( flag_eval_github_env )); then
      unset flag_eval_github_env

      gh_eval_github_env
    fi

    while (( ${#@} )); do
      eval "$1" || return $? # interrupt loop on error
      shift
    done
  fi
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  ! tkl_get_include_nest_level || tkl_execute_calls -s gh || exit $? # execute init functions only after the last include and exit on first error

  gh_eval_from_args "$@"
fi
