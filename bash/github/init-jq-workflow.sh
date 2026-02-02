#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
[[ -n "$BASH" ]] || return 0 || exit 0 # exit to avoid continue if the return can not be called

# check inclusion guard if script is included
[[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]] || (( ! SOURCE_GHWF_INIT_JQ_WORKFLOW_SH )) || return 0 || exit 0 # exit to avoid continue if the return can not be called

SOURCE_GHWF_INIT_JQ_WORKFLOW_SH=1 # including guard

if [[ -z "$GH_WORKFLOW_ROOT" ]]; then
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
fi

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?

tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-basic-workflow.sh"


function jq_init()
{
  ! tkl_is_call_registered gh jq_init || return 255

  echo "${FUNCNAME[0]}:"

  # always print the path and version of all tools to compare it between pipeline runs

  if ! gh_call which jq; then
    echo "${FUNCNAME[0]}: \`jq\` is not found."
    return 255
  fi

  gh_call jq --version

  return 0
}

function jq_is_null()
{
  (( ${#@} )) || return 255
  eval "[[ -z \"\$$1\" || \"\$$1\" == 'null' ]]" || return 1
  return 0
}

function jq_fix_null()
{
  local __var_name
  local __arg
  for __arg in "$@"; do
    __var_name="${__arg%%:*}"
    jq_is_null "$__var_name" && \
      if [[ "$__arg" != "$__var_name" ]]; then
        tkl_declare "$__var_name" "${__arg#*:}"
      else
        tkl_declare "$__var_name" ''
      fi
  done
}

tkl_register_call gh jq_init

tkl_set_return
