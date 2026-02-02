#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# Script both for execution and inclusion.
[[ -n "$BASH" ]] || return 0 || exit 0 # exit to avoid continue if the return can not be called

# check inclusion guard if script is included
[[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]] || (( ! SOURCE_GHWF_IS_FLAG_TRUE_IN_FLAGS_EXPR_STRING_SH )) || return 0 || exit 0 # exit to avoid continue if the return can not be called

SOURCE_GHWF_IS_FLAG_TRUE_IN_FLAGS_EXPR_STRING_SH=1 # including guard

if [[ -z "$GH_WORKFLOW_ROOT" ]]; then
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
fi

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?

tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-basic-workflow.sh"


# String of flag values list in format of `NAME[=[EXPR]]` ready to be evaluated as a shell array: `(<0> <1> ... <N>)`.
# If `EXPR` is not empty and begins by '[' then, use `eval EXPR` instead of `(( EXPR ))` expression.
# Otherwise if a flag expression is `NAME=`, then false (unflagged).
# Otherwise if a flag expression is `NAME`, then true (flagged).
#
# Flag expression example:
#   A is true, B is true, C is false, D is true, F is false, T is true.
#   FLAGS=`A=1 B="1 + 1" C="1 - 1" D='[[ "1" -eq "1" ]]' F= T`
#
# USAGE:
#   if gh_is_flag_true_in_flags_expr_string "$FLAGS" A; then ...; fi
#
function gh_is_flag_true_in_flags_expr_string()
{
  local __flags_expr_string="$1"
  local __flag_name="$2"

  local __flags
  local __arg
  local __name
  local __value

  local IFS

  eval __flags=($__flags_expr_string)
  for __arg in "${__flags[@]}"; do
    IFS=$'=\n' read -r -d '' __name __value <<< "$__arg"
    if [[ "$__name" == "$__flag_name" ]]; then
      # If `__value` is not empty and begins by '[' then, use `eval "$__value"` instead of `(( __value ))` expression.
      # Otherwise if `__value` is empty and `__arg` with assign character, then false (unflagged).
      # Otherwise if `__value` is empty and `__arg` without assign character, then true (flagged).
      if [[ -z "$__value" && "${__arg/=/}" == "$__arg" ]] || ( [[ "${__value:0:1}" != "[" ]] && (( __value )) ) || ( [[ "${__value:0:1}" == "[" ]] && eval "$__value" ) ; then
        return 0
      fi
    fi
  done

  return 255
}

if [[ -z "$BASH_LINENO" || BASH_LINENO[0] -eq 0 ]]; then
  # Script was not included, then execute it.
  tkl_get_include_nest_level && tkl_execute_calls gh # execute init functions only after the last include

  gh_is_flag_true_in_flags_expr_string "$@"
fi
