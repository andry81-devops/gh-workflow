#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
if [[ -n "$BASH" ]]; then

[[ -z "$GH_WORKFLOW_ROOT" ]] && {
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
}

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?

tkl_include_or_abort "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/baselib.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/funclib.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/traplib.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/hashlib.sh"


fi
