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

# format: <message> | <notice_message> <changelog_message>
function print_notice_and_changelog_text_ln()
{
  local notice_msg="$1"
  local changelog_msg="$2"

  (( ENABLE_GENERATE_CHANGELOG_FILE && ${#@} < 2 )) && changelog_msg="$notice_msg"

  print_notice "$notice_msg"

  (( ENABLE_GENERATE_CHANGELOG_FILE )) && CHANGELOG_BUF_STR="${CHANGELOG_BUF_STR}${changelog_msg}\r\n"
}

# format: <message> | <notice_message> <changelog_message>
function print_notice_and_changelog_text_bullet_ln()
{
  local notice_msg="$1"
  local changelog_msg="$2"

  (( ENABLE_GENERATE_CHANGELOG_FILE && ${#@} < 2 )) && changelog_msg="$notice_msg"

  print_notice "$notice_msg"

  (( ENABLE_GENERATE_CHANGELOG_FILE )) && CHANGELOG_BUF_STR="${CHANGELOG_BUF_STR}* notice: ${changelog_msg}\r\n"
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  print_notice "$@"
fi

fi
