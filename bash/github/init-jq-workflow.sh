#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
[[ -z "$BASH" || (-n "$SOURCE_GHWF_INIT_JQ_WORKFLOW_SH" && SOURCE_GHWF_INIT_JQ_WORKFLOW_SH -ne 0) ]] && return

SOURCE_GHWF_INIT_JQ_WORKFLOW_SH=1 # including guard

if [[ -z "$GH_WORKFLOW_ROOT" ]]; then
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
fi

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?


function jq_init()
{
  # always print the path and version of all tools to compare it between pipeline runs

  local jq_which="$(which jq 2> /dev/null)"

  if [[ -z "$jq_which" ]]; then
    echo "${FUNCNAME[0]}: \`jq\` is not found."
    return 255
  fi

  echo "${FUNCNAME[0]}:"$'\n'"$jq_which"
  echo

  echo '>jq --version'
  jq --version
  echo '<'
}

function jq_is_null()
{
  (( ! ${#@} )) && return 255
  eval "[[ -z \"\$$1\" || \"\$$1\" == 'null' ]]" && return 0
  return 1
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
