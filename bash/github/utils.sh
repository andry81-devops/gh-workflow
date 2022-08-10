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


function gh_trim_trailing_line_return_chars()
{
  local str="$1"

  while [[ "${str%[$'\r\n']}" != "$str" ]]; do
    str="${str%[$'\r\n']}"
  done

  RETURN_VALUE="$str"
}

tkl_set_return
