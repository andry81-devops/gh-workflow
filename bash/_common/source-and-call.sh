#!/usr/bin/env bash

# Script can be ONLY executed.
[[ -n "$BASH" && (-z "$BASH_LINENO" || BASH_LINENO[0] -le 0) ]] || return 0 || exit 0 # exit to avoid continue if the return can not be called

if [[ -z "$GH_WORKFLOW_ROOT" ]]; then
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
fi

# first parameter is source file
if [[ -n "$1" && "$1" != '.' ]]; then
  source "$1" || exit $?
fi

# second parameter to call with arguments, execute unconditionally
$2 "${@:3}"
