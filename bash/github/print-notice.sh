#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
if [[ -n "$BASH" ]]; then

function print_notice()
{
  local arg
  for arg in "$@"; do
    if [[ -n "$GITHUB_ACTIONS" ]]; then
      echo "::notice ::$arg"
    else
      echo "$arg"
    fi
  done
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  print_notice "$@"
fi

fi
