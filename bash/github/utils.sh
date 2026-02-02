#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script can be ONLY included by "source" command.
[[ -n "$BASH" && (-z "$BASH_LINENO" || BASH_LINENO[0] -gt 0) ]] && (( ! SOURCE_GHWF_GITHUB_UTILS_SH )) || return 0 || exit 0 # exit to avoid continue if the return can not be called

SOURCE_GHWF_GITHUB_UTILS_SH=1 # including guard

if [[ -z "$GH_WORKFLOW_ROOT" ]]; then
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
fi

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?

tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/_common/utils.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/is-flag-true-in-flags-expr-string.sh"


# CAUTION:
#
#   By default `GITHUB_ENV` variables applies on the next GitHub Actions job step!
#
function gh_set_env_var()
{
  [[ -n "$GITHUB_ACTIONS" ]] || return 0

  local __var="$1"
  local __value="$2"

  local __line

  case "$__var" in
    # ignore system and builtin variables
    __* | GITHUB_* | 'IFS') ;;
    *)
      tkl_export "$__var" "$__value" # export because GitHub does export too

      # Process line returns differently to avoid `Invalid environment variable format` error.
      #
      #   https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#setting-an-environment-variable
      #
      if [[ "${__value/[$'\r\n']/}" != "$__value" ]]; then
        echo "$__var<<::EOF::"
        echo "$__value"
        echo "::EOF::"
      else
        echo "$__var=$__value"
      fi
      ;;
  esac >> "$GITHUB_ENV"
}

function gh_unset_env_var()
{
  [[ -n "$GITHUB_ACTIONS" ]] || return 0

  local __var="$1"

  local __line

  case "$__var" in
    # ignore system and builtin variables
    __* | GITHUB_* | 'IFS') ;;
    *)
      unset "$__var"

      echo "$__var="
      ;;
  esac >> "$GITHUB_ENV"
}

function gh_set_github_env_var()
{
  [[ -n "$GITHUB_ACTIONS" ]] || return 0

  local __var="$1"

  case "$__var" in
    # ignore system and builtin variables
    __* | GITHUB_* | 'IFS') ;;
    *)
      eval "echo \"\$__var=\$$__var\""
      ;;
  esac >> "$GITHUB_ENV"
}

function gh_unset_github_env_var()
{
  [[ -n "$GITHUB_ACTIONS" ]] || return 0

  local __var="$1"

  case "$__var" in
    # ignore system and builtin variables
    __* | GITHUB_* | 'IFS') ;;
    *)
      echo "$__var="
      ;;
  esac >> "$GITHUB_ENV"
}

# $1 - stack entry name
# $2 - variable name
# $3 - variable value
#
function gh_pushset_var_to_stack()
{
  tkl_pushset_var_to_stack "$@" && {
    gh_set_github_env_var tkl__vars_stack__$1__$2__size
    gh_set_github_env_var tkl__vars_stack__$1__$2__$(( tkl__vars_stack__$1__$2__size - 1 ))
    gh_set_github_env_var tkl__vars_stack__$1__$2__$(( tkl__vars_stack__$1__$2__size - 1 ))__defined
    gh_set_github_env_var $2
    return 0
  }
}

# $1 - stack entry name
# $2 - variable name
#
function gh_pushunset_var_to_stack()
{
  tkl_pushunset_var_to_stack && {
    gh_set_github_env_var tkl__vars_stack__$1__$2__size
    gh_set_github_env_var tkl__vars_stack__$1__$2__$(( tkl__vars_stack__$1__$2__size - 1 ))
    gh_set_github_env_var tkl__vars_stack__$1__$2__$(( tkl__vars_stack__$1__$2__size - 1 ))__defined
    gh_unset_github_env_var $2
    return 0
  }
}

# $1 - stack entry name
# $2 - variable name
#
function gh_push_var_to_stack()
{
  tkl_push_var_to_stack "$@" && {
    gh_set_github_env_var tkl__vars_stack__$1__$2__size
    gh_set_github_env_var tkl__vars_stack__$1__$2__$(( tkl__vars_stack__$1__$2__size - 1 ))
    gh_set_github_env_var tkl__vars_stack__$1__$2__$(( tkl__vars_stack__$1__$2__size - 1 ))__defined
    return 0
  }
}

# $1 - stack entry name
# $2 - variable name
#
function gh_pop_var_from_stack()
{
  tkl_pop_var_from_stack "$@" && {
    if (( tkl__vars_stack__$1__$2__size )); then
      gh_unset_github_env_var tkl__vars_stack__$1__$2__$(( tkl__vars_stack__$1__$2__size ))
      gh_unset_github_env_var tkl__vars_stack__$1__$2__$(( tkl__vars_stack__$1__$2__size ))__defined
      gh_set_github_env_var tkl__vars_stack__$1__$2__size
      gh_set_github_env_var tkl__vars_stack__$1__$2__$(( tkl__vars_stack__$1__$2__size - 1 ))
      gh_set_github_env_var tkl__vars_stack__$1__$2__$(( tkl__vars_stack__$1__$2__size - 1 ))__defined
    else
      gh_unset_github_env_var tkl__vars_stack__$1__$2__size
      gh_unset_github_env_var tkl__vars_stack__$1__$2__0
      gh_unset_github_env_var tkl__vars_stack__$1__$2__0__defined
    fi
    gh_set_github_env_var $2
    return 0
  }
}

tkl_set_return
