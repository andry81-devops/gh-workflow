#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
[[ -n "$BASH" ]] || return 0 || exit 0 # exit to avoid continue if the return can not be called

# check inclusion guard if script is included
[[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]] || (( ! SOURCE_GHWF_PRINT_WARNING_LN_SH )) || return 0 || exit 0 # exit to avoid continue if the return can not be called

SOURCE_GHWF_PRINT_WARNING_LN_SH=1 # including guard

if [[ -z "$GH_WORKFLOW_ROOT" ]]; then
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
fi

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?

tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/print-warning.sh"


if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  ! tkl_get_include_nest_level || tkl_execute_calls -s gh || exit $? # execute init functions only after the last include and exit on first error

  gh_print_warning_ln "$@"
fi
