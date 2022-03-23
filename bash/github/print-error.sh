#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
if [[ -n "$BASH" ]]; then

function print_error()
{
  local arg
  for arg in "$@"; do
    if [[ -n "$GITHUB_ACTIONS" ]]; then
      echo "::error ::$arg" >&2
    else
      echo "$arg" >&2
    fi
  done
}

# format: <message> | <error_message> <changelog_message>
function print_error_and_changelog_text_bullet_ln()
{
  local error_msg="$1"
  local changelog_msg="$2"

  (( ENABLE_GENERATE_CHANGELOG_FILE && ${#@} < 2 )) && changelog_msg="$error_msg"

  print_error "$error_msg"

  (( ENABLE_GENERATE_CHANGELOG_FILE )) && CHANGELOG_BUF_STR="${CHANGELOG_BUF_STR}* error: ${changelog_msg}\r\n"
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  print_error "$@"
fi

fi
