#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
if [[ -n "$BASH" ]]; then

function set_env_from_args()
{
  [[ -z "$GITHUB_ACTIONS" ]] && return

  local i
  for (( i=1; i <= ${#@}; i++ )); do
    eval "echo \"\$$i\"" >> $GITHUB_ENV
  done
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  set_env_from_args "$@"
fi

fi
