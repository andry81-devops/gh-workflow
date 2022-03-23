#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
if [[ -n "$BASH" ]]; then

[[ -z "$stats_dir" ]] && {
  print_error "$0: error: \`stats_dir\` variable must be defined."
  exit 255
}

[[ ! -d "$stats_dir" ]] && {
  print_error "$0: error: \`stats_dir\` directory is not found: \`$stats_dir\`"
  exit 255
}

[[ -n "$stats_json" && ! -f "$stats_json" ]] && {
  print_error "$0: error: \`stats_json\` file is not found: \`$stats_json\`"
  exit 255
}

set_return 0

fi
