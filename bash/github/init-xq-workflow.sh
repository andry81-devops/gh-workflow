#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# NOTE:
#
#   Xml specific system variables (to use):
#
#     * XQ_CMDLINE_READ
#

# CAUTION:
#
#   An Xml Query command lines designed to be able to run independently to these implementations:
#
#   * https://github.com/kislyuk/xq     - a `xq` wrapper (default Cygwin distribution)
#   * xmlstarlet                        - apt-get module (available for Ubuntu 20.04)
#

# Script both for execution and inclusion.
[[ -z "$BASH" || (-n "$SOURCE_GHWF_INIT_XQ_WORKFLOW_SH" && SOURCE_GHWF_INIT_XQ_WORKFLOW_SH -ne 0) ]] && return

SOURCE_GHWF_INIT_XQ_WORKFLOW_SH=1 # including guard

if [[ -z "$GH_WORKFLOW_ROOT" ]]; then
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
fi

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?


function xq_init()
{
  # CAUTION:
  #   Array instead of string is required here for correct expansion!
  #

  case "$OSTYPE" in
    cygwin*)
      which xq > /dev/null || return $?

      local xq_help="$(yq --help)"

      if grep 'https://github.com/kislyuk/xq[/ ]' - <<< "$xq_help" >/dev/null; then
        XQ_CMDLINE_READ=(xq -c -r)
      else
        XQ_CMDLINE_READ=(xq)
      fi
      ;;

    linux*)
      which xmlstarlet > /dev/null || return $?

      XMLSTARLET_CMDLINE_SEL=(xmlstarlet sel)
      ;;

    *)
      return 255
      ;;
  esac

  return 0
}

xq_init || exit $?


function xq_is_null()
{
  (( ! ${#@} )) && return 255
  eval "[[ -z \"\$$1\" || \"\$$1\" == 'null' ]]" && return 0
  return 1
}

function xq_fix_null()
{
  local __var_name
  local __arg
  for __arg in "$@"; do
    __var_name="${__arg%%:*}"
    xq_is_null "$__var_name" && \
      if [[ "$__arg" != "$__var_name" ]]; then
        tkl_declare "$__var_name" "${__arg#*:}"
      else
        tkl_declare "$__var_name" ''
      fi
  done
}

tkl_set_return
