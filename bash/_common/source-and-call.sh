#!/bin/bash

# Script can be ONLY executed.
[[ -z "$BASH" || (-n "$BASH_LINENO" && BASH_LINENO[0] -gt 0) ]] && return

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
