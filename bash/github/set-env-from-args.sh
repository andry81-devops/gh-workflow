#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

[[ -z "$BASH" || (-n "$SOURCE_GHWF_SET_ENV_FROM_ARGS_SH" && SOURCE_GHWF_SET_ENV_FROM_ARGS_SH -ne 0) ]] && return

SOURCE_GHWF_SET_ENV_FROM_ARGS_SH=1 # including guard

if [[ -z "$GH_WORKFLOW_ROOT" ]]; then
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
fi

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?


tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-basic-workflow.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/utils.sh"


function gh_set_env_from_args()
{
  [[ -z "$GITHUB_ACTIONS" ]] && return 0

  local IFS
  local __arg
  local __var
  local __value

  for __arg in "$@"; do
    IFS='=' read -r __var __value <<< "$__arg"

    gh_set_env_var "$__var" "$__value"
  done
}

tkl_get_include_nest_level && tkl_execute_calls gh # execute init functions only after the last include

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  gh_set_env_from_args "$@"
fi
