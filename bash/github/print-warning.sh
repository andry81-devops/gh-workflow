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
    if [[ -n "$GITHUB_ACTIONS" ]]; then
      echo "::warning ::$arg" >&2
    else
      echo "$arg" >&2
    fi
  done
}

# format: <message> | <warning_message> <changelog_message>
function print_warning_and_changelog_text_bullet_ln()
{
  local warning_msg="$1"
  local changelog_msg="$2"

  (( ENABLE_GENERATE_CHANGELOG_FILE && ${#@} < 2 )) && changelog_msg="$warning_msg"

  print_warning "$warning_msg"

  (( ENABLE_GENERATE_CHANGELOG_FILE )) && CHANGELOG_BUF_STR="${CHANGELOG_BUF_STR}* warning: ${changelog_msg}\r\n"
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  print_warning "$@"
fi

fi
