#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
[[ -z "$BASH" || (-n "$SOURCE_GHWF_INIT_STATS_WORKFLOW_SH" && SOURCE_GHWF_INIT_STATS_WORKFLOW_SH -ne 0) ]] && return

SOURCE_GHWF_INIT_STATS_WORKFLOW_SH=1 # including guard

if [[ -z "$GH_WORKFLOW_ROOT" ]]; then
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
fi

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?


if [[ -z "$stats_dir" ]]; then
  gh_print_error_ln "$0: error: \`stats_dir\` variable must be defined."
  exit 255
fi

if [[ ! -d "$stats_dir" ]]; then
  gh_print_error_ln "$0: error: \`stats_dir\` directory is not found: \`$stats_dir\`"
  exit 255
fi

if [[ -n "$stats_json" && ! -f "$stats_json" ]]; then
  gh_print_error_ln "$0: error: \`stats_json\` file is not found: \`$stats_json\`"
  exit 255
fi

tkl_set_return
