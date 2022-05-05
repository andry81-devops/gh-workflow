#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
[[ -z "$BASH" || (-n "$SOURCE_GHWF_INIT_STATS_WORKFLOW_SH" && SOURCE_GHWF_INIT_STATS_WORKFLOW_SH -ne 0) ]] && return

SOURCE_GHWF_INIT_STATS_WORKFLOW_SH=1 # including guard

[[ -z "$GH_WORKFLOW_ROOT" ]] && {
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
}

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?


[[ -z "$stats_dir" ]] && {
  gh_print_error_ln "$0: error: \`stats_dir\` variable must be defined."
  exit 255
}

[[ ! -d "$stats_dir" ]] && {
  gh_print_error_ln "$0: error: \`stats_dir\` directory is not found: \`$stats_dir\`"
  exit 255
}

[[ -n "$stats_json" && ! -f "$stats_json" ]] && {
  gh_print_error_ln "$0: error: \`stats_json\` file is not found: \`$stats_json\`"
  exit 255
}

tkl_set_return
