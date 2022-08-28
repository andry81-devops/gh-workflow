#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
[[ -z "$BASH" || (-n "$SOURCE_GHWF_INIT_XQ_WORKFLOW_SH" && SOURCE_GHWF_INIT_XQ_WORKFLOW_SH -ne 0) ]] && return

SOURCE_GHWF_INIT_XQ_WORKFLOW_SH=1 # including guard

[[ -z "$GH_WORKFLOW_ROOT" ]] && {
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
}

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?


function xq_init()
{
  which xq > /dev/null || return $?

  return 0
}

xq_init || exit $?


function xq_is_null()
{
  (( ! ${#@} )) && return 255
  eval "[[ -z \"\$$1\" || \"\$$1\" == 'null' ]]" && return 0
  return 1
}

function xq_fix_null()
{
  local __var_name
  local __arg
  for __arg in "$@"; do
    __var_name="${__arg%%:*}"
    xq_is_null "$__var_name" && \
      if [[ "$__arg" != "$__var_name" ]]; then
        tkl_declare "$__var_name" "${__arg#*:}"
      else
        tkl_declare "$__var_name" ''
      fi
  done
}

tkl_set_return
