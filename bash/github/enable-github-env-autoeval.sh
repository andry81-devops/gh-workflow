#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
[[ -z "$BASH" || (-n "$SOURCE_GHWF_ENABLE_GITHUB_ENV_AUTOEVAL_SH" && SOURCE_GHWF_ENABLE_GITHUB_ENV_AUTOEVAL_SH -ne 0) ]] && return

SOURCE_GHWF_ENABLE_GITHUB_ENV_AUTOEVAL_SH=1 # including guard

[[ -z "$GH_WORKFLOW_ROOT" ]] && {
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
}

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?

tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-github-workflow.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/utils.sh"


function gh_enable_github_auto_eval()
{
  [[ -z "$GITHUB_ACTIONS" ]] && return 0

  if [[ -z "${GHWF_GITHUB_ENV_AUTOEVAL:+x}" ]]; then # to save veriable between workflow steps
    gh_set_env_var GHWF_GITHUB_ENV_AUTOEVAL  1
  fi
}

function gh_disable_github_auto_eval()
{
  [[ -z "$GITHUB_ACTIONS" ]] && return 0

  gh_unset_env_var GHWF_GITHUB_ENV_AUTOEVAL
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  gh_enable_github_auto_eval "$@"
fi
