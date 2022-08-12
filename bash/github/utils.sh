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


function gh_set_env_var()
{
  local var="$1"
  local value="$2"

  local IFS
  local line

  if [[ -n "$GITHUB_ACTIONS" ]]; then
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

tkl_set_return
