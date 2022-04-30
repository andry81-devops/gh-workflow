#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# NOTE:
#
#   Yaml specific variables:
#
#     * ENABLE_YAML_PRINT_AFTER_EDIT
#     * ENABLE_YAML_DIFF_PRINT_AFTER_EDIT
#

# CAUTION:
#
#   The `yq` command lines designed to be able to run independently to these `yq` implementations:
#
#   * `github.com/kislyuk/yq`   - a `jq` wrapper (default Cygwin distribution)
#   * `github.com/mikefarah/yq` - Go implementation (default Ubuntu 20.04 distribution)
#

# Script both for execution and inclusion.
if [[ -n "$BASH" ]]; then

[[ -z "$GH_WORKFLOW_ROOT" ]] && {
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
}

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?

which yq > /dev/null || exit $?


function yq_is_null()
{
  (( ! ${#@} )) && return 255
  eval "[[ -z \"\$$1\" || \"\$$1\" == 'null' ]]" && return 0
  return 1
}

function yq_fix_null()
{
  local __var_name
  local __arg
  for __arg in "$@"; do
    __var_name="${__arg%%:*}"
    yq_is_null "$__var_name" && \
      if [[ "$__arg" != "$__var_name" ]]; then
        tkl_declare "$__var_name" "${__arg#*:}"
      else
        tkl_declare "$__var_name" ''
      fi
  done
}

function yq_edit()
{
  if [[ -z "$TEMP_DIR" || ! -d "$TEMP_DIR" ]]; then
    echo "$0: error: `TEMP_DIR` directory must be defined and exist: \`$TEMP_DIR\`." >&2
    return 255
  fi

  local edit_file_name="$1"
  local input_file="$2"
  local output_file="$3"
  local edit_list
  local last_error

  edit_list=( "${@:4}" )

  local i=0
  local j=1

  function on_return_handler()
  {
    if (( ENABLE_YAML_PRINT_AFTER_EDIT )); then
      echo ">\`$TEMP_DIR/${edit_file_name}-edit0.yml\`:"
      echo "$(<"$TEMP_DIR/${edit_file_name}-edit0.yml")"
      echo '<'
    fi
  }

  # on return handler
  tkl_push_trap 'on_return_handler' RETURN

  yq -y \
    "${edit_list[0]}" \
    "$input_file" > "$TEMP_DIR/${edit_file_name}-edit0.yml" || return $?

  local arg
  for arg in "${edit_list[@]:1}"; do
    function on_return_handler()
    {
      if (( ENABLE_YAML_PRINT_AFTER_EDIT )); then
        echo ">\`$TEMP_DIR/${edit_file_name}-edit${j}.yml\`:"
        echo "$(<"$TEMP_DIR/${edit_file_name}-edit${j}.yml")"
        echo '<'
      fi
    }

    yq -y \
      "$arg" \
      "$TEMP_DIR/${edit_file_name}-edit${i}.yml" > "$TEMP_DIR/${edit_file_name}-edit${j}.yml" || return $?

    i=$j
    (( j++ ))
  done

  mv -Tf "$TEMP_DIR/${edit_file_name}-edit${i}.yml" "$output_file"
  last_error=$?

  if [[ ! -f "$TEMP_DIR/${edit_file_name}-edit${i}.yml" ]]; then
    function on_return_handler()
    {
      if (( ENABLE_YAML_PRINT_AFTER_EDIT )); then
        echo ">\`$output_file\`:"
        echo "$(<"$output_file")"
        echo '<'
      fi
    }
  fi

  return $last_error
}

function yq_diff()
{
  local input_file_before="$1"
  local input_file_after="$2"
  local output_diff_file="$3"

  local last_error

  #  0     No differences were found. 
  #  1     Differences were found.
  # >1     An error occurred.
  #
  diff -awB \
    <(grep -vE '^\s*(#|$)' "$input_file_before") \
    "$input_file_after" > "$output_diff_file"
  last_error=$?

  (( last_error > 1 )) && return $last_error

  if (( ENABLE_YAML_DIFF_PRINT_AFTER_EDIT )); then
    echo ">\`$output_diff_file\`:"
    echo "$(<"$output_diff_file")"
    echo '<'
  fi

  return 0
}

function yq_patch()
{
  local input_file="$1"
  local input_diff_file="$2"
  local temp_file="$3"
  local output_file="$4"

  patch -Nlt --merge -o "$temp_file" -i "$input_diff_file" "$input_file" && \
  mv -Tf "$temp_file" "$output_file"
}

[[ -z "$ENABLE_YAML_PRINT_AFTER_EDIT" ]] && ENABLE_YAML_PRINT_AFTER_EDIT=0
[[ -z "$ENABLE_YAML_DIFF_PRINT_AFTER_EDIT" ]] && ENABLE_YAML_DIFF_PRINT_AFTER_EDIT=0

tkl_set_return

fi
