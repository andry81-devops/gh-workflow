#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
[[ -z "$BASH" || (-n "$SOURCE_GHWF_INIT_CURL_WORKFLOW_SH" && SOURCE_GHWF_INIT_CURL_WORKFLOW_SH -ne 0) ]] && return

SOURCE_GHWF_INIT_CURL_WORKFLOW_SH=1 # including guard

if [[ -z "$GH_WORKFLOW_ROOT" ]]; then
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
fi

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?

tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-basic-workflow.sh"


function curl_print_response_if_error()
{
  local last_error=$?

  (( ! ENABLE_PRINT_CURL_RESPONSE_ON_ERROR )) && return $last_error
  (( ! last_error )) && return $last_error

  if [[ -z "$TEMP_DIR" ]]; then # otherwise use exterenal TEMP_DIR
    TEMP_DIR="$(mktemp -d)"

    tkl_push_trap 'rm -rf "$TEMP_DIR"' RETURN
  fi

  local response_file="${1:-"$TEMP_DIR/response.txt"}"

  [[ ! -f "$response_file" ]] && return 255

  read -r -d '' curl_response_file < "$response_file" || return 255

  # CAUTION:
  #   As a single line to reduce probability of mix with the stderr.
  #
  echo "CURL RESPONSE:"$'\r\n'"$curl_response_file"$'\r\n---'

  return $last_error
}

tkl_set_return
