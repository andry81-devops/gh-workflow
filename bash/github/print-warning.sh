#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
if [[ -n "$BASH" ]]; then

function print_warning()
{
  local arg
  for arg in "$@"; do
    echo "$arg" >&2
    [[ -n "$GITHUB_ACTIONS" ]] && echo "::warning ::$arg"
  done
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  print_warning "$@"
fi

fi
