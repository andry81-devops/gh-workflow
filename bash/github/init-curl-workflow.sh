#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
[[ -z "$BASH" || (-n "$SOURCE_GHWF_INIT_CURL_WORKFLOW_SH" && SOURCE_GHWF_INIT_CURL_WORKFLOW_SH -ne 0) ]] && return

SOURCE_GHWF_INIT_CURL_WORKFLOW_SH=1 # including guard

[[ -z "$GH_WORKFLOW_ROOT" ]] && {
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
}

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?


function curl_print_response_if_error()
{
  local last_error=$?
  local response_file="${1:-"$TEMP_DIR/response.txt"}"

  (( ! ENABLE_PRINT_CURL_RESPONSE_ON_ERROR )) && return
  (( ! last_error )) && return

  [[ ! -f "$response_file" ]] && return

  read -r -d '' curl_response_file < "$response_file" || return

  # CAUTION:
  #   As a single line to reduce probability of mix with the stderr.
  #
  echo "CURL RESPONSE:"$'\r\n'"$curl_response_file"$'\r\n---'
}

tkl_set_return
