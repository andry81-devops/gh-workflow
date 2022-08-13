#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
[[ -z "$BASH" || (-n "$SOURCE_GHWF_UTILS_SH" && SOURCE_GHWF_UTILS_SH -ne 0) ]] && return

SOURCE_GHWF_UTILS_SH=1 # including guard

[[ -z "$GH_WORKFLOW_ROOT" ]] && {
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
}

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?


# CAUTION:
#
#   Assignment applies ONLY between GitHub Actions job steps!
#
function gh_set_env_var()
{
  [[ -z "$GITHUB_ACTIONS" ]] && return 0

  local var="$1"
  local value="$2"

  local IFS
  local line

  # Process line returns differently to avoid `Invalid environment variable format` error.
  #
  #   https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#setting-an-environment-variable
  #
  if [[ "${value//[$'\r\n']/}" != "$value" ]]; then
    {
      echo "$var<<::EOF::"
      IFS=$'\n'; for line in "$value"; do
        echo "$line"
      done
      echo "::EOF::"
    } >> $GITHUB_ENV
  else
    echo "$var=$value" >> $GITHUB_ENV
  fi
}

function gh_trim_trailing_line_return_chars()
{
  local str="$1"

  while [[ "${str%[$'\r\n']}" != "$str" ]]; do
    str="${str%[$'\r\n']}"
  done

  RETURN_VALUE="$str"
}

function gh_encode_line_return_chars()
{
  local line="$1"

  RETURN_VALUE="${line//$'\r'/%0D}"
  RETURN_VALUE="${RETURN_VALUE//$'\n'/%0A}"
}

function gh_decode_line_return_chars()
{
  local line="$1"

  RETURN_VALUE="${line//%0D/$'\r'}"
  RETURN_VALUE="${RETURN_VALUE//%0A/$'\n'}"
}

tkl_set_return
