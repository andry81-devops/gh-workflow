#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
[[ -z "$BASH" || (-n "$SOURCE_GHWF_END_PRINT_ANNOTATION_GROUP_SH" && SOURCE_GHWF_END_PRINT_ANNOTATION_GROUP_SH -ne 0) ]] && return

SOURCE_GHWF_END_PRINT_ANNOTATION_GROUP_SH=1 # including guard

if [[ -z "$GH_WORKFLOW_ROOT" ]]; then
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
fi

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?

tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-print-workflow.sh"


tkl_get_include_nest_level && tkl_execute_calls gh # execute init functions only after the last include

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  gh_end_print_annotation_group "$@"
fi
