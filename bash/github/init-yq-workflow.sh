#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# NOTE:
#
#   Yaml specific system variables (to use):
#
#     * YQ_CMDLINE_READ
#     * YQ_CMDLINE_READ_AS_YAML
#     * YQ_CMDLINE_WRITE
#     * YQ_DIFF_ALL_CMDLINE
#     * YQ_DIFF_NO_BLANKS_CMDLINE
#     * YQ_PATCH_DIFF_CMDLINE
#
#   Yaml specific user variables (to set):
#
#     * ENABLE_YAML_PRINT_AFTER_EDIT
#     * ENABLE_YAML_PRINT_AFTER_PATCH
#     * ENABLE_YAML_DIFF_PRINT_AFTER_EDIT
#     * ENABLE_YAML_DIFF_PRINT_BEFORE_PATCH
#     * ENABLE_YAML_PATCH_DIFF_PAUSE_MODE
#
#     * ENABLE_YAML_PRINT_ALL                       # debug: to enable all prints altogether
#

# CAUTION:
#
#   The `yq` command lines designed to be able to run independently to these `yq` implementations:
#
#   * https://github.com/kislyuk/yq     - a `jq` wrapper (default Cygwin distribution)
#   * https://github.com/mikefarah/yq   - Go implementation (default Ubuntu 20.04 distribution)
#

# Usage example:
#
# >
# yq_edit "<prefix-name>" "<suffix-name>" "<input-yaml>" "$TEMP_DIR/<output-yaml-edited>" \
#   <list-of-yq-eval-strings> && \
#   yq_diff "$TEMP_DIR/<output-yaml-edited>" "<input-yaml>" "$TEMP_DIR/<output-diff-edited>" && \
#   yq_restore_edited_uniform_diff "$TEMP_DIR/<output-diff-edited>" "$TEMP_DIR/<output-diff-edited-restored>" && \
#   yq_patch "$TEMP_DIR/<output-yaml-edited>" "$TEMP_DIR/<output-diff-edited-restored>" "$TEMP_DIR/<output-yaml-edited-restored>" "<output-yaml>" ["<input-yaml>"]
#
# , where:
#
#   <prefix-name> - prefix name part for files in the temporary directory
#   <suffix-name> - suffix name part for files in the temporary directory
#
#   <input-yaml>  - input yaml file path
#   <output-yaml> - output yaml file path
#
#   <output-yaml-edited>          - output file name of edited yaml
#   <output-diff-edited>          - output file name of difference file generated from edited yaml
#   <output-diff-edited-restored> - output file name of restored difference file generated from original difference file
#   <output-yaml-edited-restored> - output file name of restored yaml file stored as intermediate temporary file
#

# Script both for execution and inclusion.
[[ -z "$BASH" || (-n "$SOURCE_GHWF_INIT_YQ_WORKFLOW_SH" && SOURCE_GHWF_INIT_YQ_WORKFLOW_SH -ne 0) ]] && return

SOURCE_GHWF_INIT_YQ_WORKFLOW_SH=1 # including guard

if [[ -z "$GH_WORKFLOW_ROOT" ]]; then
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
fi

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?

tkl_include_or_abort "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/traplib.sh"

tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-diff-workflow.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/utils.sh"


function yq_init()
{
  echo "${FUNCNAME[0]}:"

  # always print the path and version of all tools to compare it between pipeline runs

  if ! gh_call which yq; then
    echo "${FUNCNAME[0]}: \`yq\` is not found."
    return 255
  fi

  gh_call yq --version

  # global variables init
  [[ -z "$ENABLE_YAML_PRINT_AFTER_EDIT" ]] &&         gh_set_env_var ENABLE_YAML_PRINT_AFTER_EDIT 0
  [[ -z "$ENABLE_YAML_PRINT_AFTER_PATCH" ]] &&        gh_set_env_var ENABLE_YAML_PRINT_AFTER_PATCH 0
  [[ -z "$ENABLE_YAML_DIFF_PRINT_AFTER_EDIT" ]] &&    gh_set_env_var ENABLE_YAML_DIFF_PRINT_AFTER_EDIT 0
  [[ -z "$ENABLE_YAML_DIFF_PRINT_BEFORE_PATCH" ]] &&  gh_set_env_var ENABLE_YAML_DIFF_PRINT_BEFORE_PATCH 0
  [[ -z "$ENABLE_YAML_PRINT_ALL" ]] &&                gh_set_env_var ENABLE_YAML_PRINT_ALL 0                # disabled by default

  if (( ENABLE_YAML_PRINT_ALL )); then
    gh_set_env_var ENABLE_YAML_PRINT_AFTER_EDIT 1
    gh_set_env_var ENABLE_YAML_PRINT_AFTER_PATCH 1
    gh_set_env_var ENABLE_YAML_DIFF_PRINT_AFTER_EDIT 1
    gh_set_env_var ENABLE_YAML_DIFF_PRINT_BEFORE_PATCH 1
  fi

  local yq_help="$(yq --help)"

  # CAUTION:
  #   Array instead of string is required here for correct expansion!
  #
  if grep 'https://github.com/mikefarah/yq[/ ]' - <<< "$yq_help" >/dev/null; then
    YQ_CMDLINE_READ=(yq)
    YQ_CMDLINE_READ_AS_YAML=(yq)
    YQ_CMDLINE_WRITE=(yq e)
  elif grep 'https://github.com/kislyuk/yq[/ ]' - <<< "$yq_help" >/dev/null; then
    # CAUTION: jq must be installed too
    tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-jq-workflow.sh"
    jq_init || return $?

    YQ_CMDLINE_READ=(yq -cr)
    YQ_CMDLINE_READ_AS_YAML=(yq -ycr)
    YQ_CMDLINE_WRITE=(yq -y)
  else
    echo "$0: error: \`yq\` implementation is not known." >&2
    return 255
  fi

  YQ_DIFF_ALL_CMDLINE=(diff -U0 -ad --horizon-lines=0 --suppress-common-lines)
  YQ_DIFF_NO_BLANKS_CMDLINE=(diff -U0 -aBd --horizon-lines=0 --suppress-common-lines)
  YQ_PATCH_DIFF_CMDLINE=(patch -Nt --merge)

  return 0
}

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

function yq_print_file()
{
  local file_path="$1"

  echo ">\`$file_path\`:"
  echo "$(<"$file_path")"
  echo '==='
}

function yq_edit()
{
  if [[ -z "$TEMP_DIR" || ! -d "$TEMP_DIR" ]]; then
    echo "$0: error: \`TEMP_DIR\` directory must be defined and exist: \`$TEMP_DIR\`." >&2
    return 255
  fi

  local prefix_name="$1"
  local suffix_name="$2"
  local input_yaml_file="$3"
  local output_yaml_edited_file="$4"
  local edit_list
  local last_error

  edit_list=( "${@:5}" )

  local i=0
  local j=1

  function on_return_handler()
  {
    if (( ENABLE_YAML_PRINT_AFTER_EDIT )); then
      yq_print_file "$TEMP_DIR/${prefix_name}-${suffix_name}-0.yml"
    fi
  }

  # on return handler
  tkl_push_trap 'on_return_handler' RETURN

  "${YQ_CMDLINE_WRITE[@]}" \
    "${edit_list[0]}" \
    "$input_yaml_file" > "$TEMP_DIR/${prefix_name}-${suffix_name}-0.yml" || return $?

  local arg
  for arg in "${edit_list[@]:1}"; do
    function on_return_handler()
    {
      if (( ENABLE_YAML_PRINT_AFTER_EDIT )); then
        yq_print_file "$TEMP_DIR/${prefix_name}-${suffix_name}-${j}.yml"
      fi
    }

    "${YQ_CMDLINE_WRITE[@]}" \
      "$arg" \
      "$TEMP_DIR/${prefix_name}-${suffix_name}-${i}.yml" > "$TEMP_DIR/${prefix_name}-${suffix_name}-${j}.yml" || return $?

    i=$j
    (( j++ ))
  done

  cp -Tf "$TEMP_DIR/${prefix_name}-${suffix_name}-${i}.yml" "$output_yaml_edited_file"
  last_error=$?

  if [[ ! -f "$TEMP_DIR/${prefix_name}-${suffix_name}-${i}.yml" ]]; then
    function on_return_handler()
    {
      if (( ENABLE_YAML_PRINT_AFTER_EDIT )); then
        yq_print_file "$output_yaml_edited_file"
      fi
    }
  fi

  return $last_error
}

function yq_diff_impl()
{
  local input_file_before="$1"
  local input_file_after="$2"
  local output_diff_file="$3"
  local diff_all="${4:-1}"

  local last_error

  #  0     No differences were found. 
  #  1     Differences were found.
  # >1     An error occurred.
  #
  if (( diff_all )); then
    "${YQ_DIFF_ALL_CMDLINE[@]}" \
      "$input_file_before" \
      "$input_file_after" > "$output_diff_file"
  else
    "${YQ_DIFF_NO_BLANKS_CMDLINE[@]}" \
      "$input_file_before" \
      "$input_file_after" > "$output_diff_file"
  fi
  last_error=$?

  (( last_error > 1 )) && return $last_error

  return 0
}

function yq_diff()
{
  yq_diff_impl "$@"
  last_error=$?

  if (( ENABLE_YAML_DIFF_PRINT_AFTER_EDIT )); then
    yq_print_file "$3"
  fi

  return $last_error
}

# Restores blank lines and comments.
#
# PROs:
#   * Can restore blank lines together with standalone comment lines: `  # ... `
#   * Can restore line end comments: `  key: value # ...`
#   * Can restore quotes around values
#   * Can detect a line remove/change/add altogether.
#
# CONs:
#   * Because of has having a guess logic, may leave artefacts or invalid corrections.
#   * Does not restore line end comments, where the yaml data is changed.
#
# Note
#   YQ implementation may not remove or add some comments. So the function must
#   correctly process these.
#
function yq_restore_edited_uniform_diff() # NOTE: Experimental
{
  local input_file_edited_diff="$1"
  local output_file_restored_diff="$2"

  local DiffChunkLines
  local DiffChunkLinesIndex
  local DiffChunkRemoveLineOffset
  local DiffChunkNumRemoveLines
  local DiffChunkAddLineOffset
  local DiffChunkNumAddLines
  local DiffChunkOffsetShift

  local AccumDiffChunkOffsetShift

  local DiffRemoveChunkLine
  local DiffRemoveChunkLineKeyText
  local DiffRemoveChunkLineFiltered
  local DiffRemoveChunkLineFilteredLen
  local DiffRemoveChunkLineBlanked
  local DiffRemoveChunkLines
  local DiffRemoveChunkLinesLen
  local DiffRemoveChunkLinesIndex

  local DiffAddChunkLine
  local DiffAddChunkLineKeyText
  local DiffAddChunkLineFiltered
  local DiffAddChunkLineFilteredLen
  local DiffAddChunkLines
  local DiffAddChunkLinesLen
  local DiffAddChunkLinesIndex
  local DiffAddChunkLinesToRemove

  local MergedDiffChunkLineLen
  local MergeDiffAddChunkLineNextIndex
  local IsDiffAddChunkLineProcessed

  diff_load_file_to_arr "$input_file_edited_diff" DiffChunkLines 1 || return 255

  DiffChunkLinesIndex=0
  DiffOffsetShift=0
  DiffRemoveChunkLines=()
  DiffRemoveChunkLinesIndex=0
  DiffAddChunkLines=()
  DiffAddChunkLinesIndex=0
  AccumDiffChunkOffsetShift=0

  while (( DiffChunkLinesIndex < ${#DiffChunkLines[@]} )); do
    diff_read_next_uniform_chunk_from_arr DiffChunkLines DiffChunkLinesIndex DiffRemoveChunkLines DiffAddChunkLines || return 255

    DiffChunkRemoveLineOffset="${RETURN_VALUES[0]}"
    DiffChunkNumRemoveLines="${RETURN_VALUES[1]}"
    DiffChunkAddLineOffset="${RETURN_VALUES[2]}"
    DiffChunkNumAddLines="${RETURN_VALUES[3]}"
    DiffChunkOffsetShift="${RETURN_VALUES[4]-0}"

    DiffRemoveChunkLinesLen="${#DiffRemoveChunkLines[@]}"
    DiffAddChunkLinesLen="${#DiffAddChunkLines[@]}"

    DiffAddChunkLinesToRemove=()

    MergeDiffAddChunkLineNextIndex=0

    if (( DiffRemoveChunkLinesLen )); then
      for (( DiffRemoveChunkLinesIndex=0; DiffRemoveChunkLinesIndex < DiffRemoveChunkLinesLen; DiffRemoveChunkLinesIndex++ )); do
        DiffRemoveChunkLine="${DiffRemoveChunkLines[DiffRemoveChunkLinesIndex]}"

        DiffRemoveChunkLineFiltered="${DiffRemoveChunkLine%$'\r'}"

        # remove all white spaces
        DiffRemoveChunkLineBlanked="${DiffRemoveChunkLineFiltered//[$'\t' ]/}"

        # WORKAROUND:
        #   `Spurious comment line duplication in yq v4.50.1` : https://github.com/mikefarah/yq/issues/2578
        #
        #   Treat line as empty if consisted only of a single `#` character.

        if [[ -z "$DiffRemoveChunkLineBlanked" || "$DiffRemoveChunkLineBlanked" == '#' ]]; then
          DiffRemoveChunkLineFiltered=''
        fi

        IsDiffAddChunkLineProcessed=0

        for (( DiffAddChunkLinesIndex = MergeDiffAddChunkLineNextIndex; DiffAddChunkLinesIndex < DiffAddChunkLinesLen; DiffAddChunkLinesIndex++ )); do
          DiffAddChunkLine="${DiffAddChunkLines[DiffAddChunkLinesIndex]}"

          DiffAddChunkLineFiltered="${DiffAddChunkLine%$'\r'}"

          (( DiffRemoveChunkLineFilteredLen = ${#DiffRemoveChunkLineFiltered} ))
          (( DiffAddChunkLineFilteredLen = ${#DiffAddChunkLineFiltered} ))

          if (( DiffAddChunkLineFilteredLen < DiffRemoveChunkLineFilteredLen )); then
            (( MergedDiffChunkLineLen = DiffAddChunkLineFilteredLen ))
          else
            (( MergedDiffChunkLineLen = DiffRemoveChunkLineFilteredLen ))
          fi

          if (( MergedDiffChunkLineLen )); then
            if [[ "${DiffRemoveChunkLineFiltered:0:MergedDiffChunkLineLen}" == "${DiffAddChunkLineFiltered:0:MergedDiffChunkLineLen}" ]]; then
              if (( DiffAddChunkLineFilteredLen < DiffRemoveChunkLineFilteredLen )); then
                # ex:
                #   -    test123: 456 # hello
                #   +    test123: 456
                #

                DiffAddChunkLines[DiffAddChunkLinesIndex]="${DiffRemoveChunkLines[DiffRemoveChunkLinesIndex]}" # restore line end comment (CAUTION: can be inaccurate)
              else
                # ex:
                #   -    test123: 456
                #   +    test123: 456 # hello
                #
                :
              fi

              (( MergeDiffAddChunkLineNextIndex = DiffAddChunkLinesIndex + 1 ))

              # unregister to remove
              unset DiffAddChunkLinesToRemove[DiffAddChunkLinesIndex]

              IsDiffAddChunkLineProcessed=1

              break
            else
              yq_get_key_line_text "$DiffRemoveChunkLineFiltered"

              DiffRemoveChunkLineKeyText="$RETURN_VALUE"

              yq_get_key_line_text "$DiffAddChunkLineFiltered"

              DiffAddChunkLineKeyText="$RETURN_VALUE"

              if [[ "$DiffRemoveChunkLineKeyText" == "$DiffAddChunkLineKeyText" ]]; then
                # ex:
                #   -    test123: 456 # hello
                #   +    test123: 789
                #

                DiffAddChunkLines[DiffAddChunkLinesIndex]="${DiffRemoveChunkLines[DiffRemoveChunkLinesIndex]}" # restore line end comment (CAUTION: can be inaccurate)

                (( MergeDiffAddChunkLineNextIndex = DiffAddChunkLinesIndex + 1 ))

                # unregister to remove
                unset DiffAddChunkLinesToRemove[DiffAddChunkLinesIndex]

                IsDiffAddChunkLineProcessed=1

                break
              elif [[ -n "$DiffAddChunkLineKeyText" ]]; then
                # yaml key is found, register to remove the line if would not processed at all
                (( DiffAddChunkLinesToRemove[DiffAddChunkLinesIndex] = 1 ))
              fi
            fi
          fi
        done

        if (( ! IsDiffAddChunkLineProcessed )); then
          # shift with not set values
          (( DiffAddChunkLinesLen++ ))

          for (( DiffAddChunkLinesIndex = DiffAddChunkLinesLen; MergeDiffAddChunkLineNextIndex < DiffAddChunkLinesIndex; DiffAddChunkLinesIndex-- )); do
            if [[ -n "${DiffAddChunkLines[DiffAddChunkLinesIndex - 1]+x}" ]]; then
              DiffAddChunkLines[DiffAddChunkLinesIndex]="${DiffAddChunkLines[DiffAddChunkLinesIndex - 1]}"
            else
              unset DiffAddChunkLines[DiffAddChunkLinesIndex]
            fi

            if [[ -n "${DiffAddChunkLinesToRemove[DiffAddChunkLinesIndex - 1]+x}" ]]; then
              DiffAddChunkLinesToRemove[DiffAddChunkLinesIndex]="${DiffAddChunkLinesToRemove[DiffAddChunkLinesIndex - 1]}"
            else
              unset DiffAddChunkLinesToRemove[DiffAddChunkLinesIndex]
            fi
          done

          DiffAddChunkLines[MergeDiffAddChunkLineNextIndex++]="${DiffRemoveChunkLines[DiffRemoveChunkLinesIndex]}" # insert

          (( DiffChunkNumAddLines++ ))
          (( DiffChunkOffsetShift++ ))
        fi
      done
    else
      for (( DiffAddChunkLinesIndex = MergeDiffAddChunkLineNextIndex; DiffAddChunkLinesIndex < DiffAddChunkLinesLen; DiffAddChunkLinesIndex++ )); do
        DiffAddChunkLine="${DiffAddChunkLines[DiffAddChunkLinesIndex]}"

        DiffAddChunkLineFiltered="${DiffAddChunkLine%$'\r'}"

        yq_get_key_line_text "$DiffAddChunkLineFiltered"

        DiffAddChunkLineKeyText="$RETURN_VALUE"

        if [[ -n "$DiffAddChunkLineKeyText" ]]; then
          # yaml key is found, remove the line
          unset DiffAddChunkLines[DiffAddChunkLinesIndex]

          (( DiffChunkNumAddLines-- ))
          (( DiffChunkOffsetShift-- ))
        fi
      done

      DiffAddChunkLinesLen="${#DiffAddChunkLines[@]}"

      if (( ! DiffAddChunkLinesLen )); then
        (( AccumDiffChunkOffsetShift += DiffChunkOffsetShift ))

        continue
      fi
    fi

    # remove chunk addition lines registered to remove
    for (( DiffAddChunkLinesIndex=0; DiffAddChunkLinesIndex < DiffAddChunkLinesLen; DiffAddChunkLinesIndex++ )); do
      if (( DiffAddChunkLinesToRemove[DiffAddChunkLinesIndex] )); then
        unset DiffAddChunkLines[DiffAddChunkLinesIndex]

        (( DiffChunkNumAddLines-- ))
        (( DiffChunkOffsetShift-- ))
      fi
    done

    (( DiffChunkAddLineOffset += AccumDiffChunkOffsetShift ))

    diff_make_uniform_chunk_header "$DiffChunkRemoveLineOffset" "$DiffChunkNumRemoveLines" "$DiffChunkAddLineOffset" "$DiffChunkNumAddLines" "$DiffChunkOffsetShift"

    (( AccumDiffChunkOffsetShift += DiffChunkOffsetShift ))

    echo "$RETURN_VALUE"

    for (( DiffRemoveChunkLinesIndex=0; DiffRemoveChunkLinesIndex < DiffRemoveChunkLinesLen; DiffRemoveChunkLinesIndex++ )); do
      if [[ -n "${DiffRemoveChunkLines[DiffRemoveChunkLinesIndex]+x}" ]]; then
        echo "-${DiffRemoveChunkLines[DiffRemoveChunkLinesIndex]}"
      fi
    done

    for (( DiffAddChunkLinesIndex=0; DiffAddChunkLinesIndex < DiffAddChunkLinesLen; DiffAddChunkLinesIndex++ )); do
      if [[ -n "${DiffAddChunkLines[DiffAddChunkLinesIndex]+x}" ]]; then
        echo "+${DiffAddChunkLines[DiffAddChunkLinesIndex]}"
      fi
    done
  done > "$output_file_restored_diff" || return 255

  return 0
}

# Gets yaml key as line text before the `:` and without trailing white spaces.
# Returning line text does include indention to be able to be compared with another line text as is.
# Ignores invalid yaml syntaxes.
#
# ex:
#   `  test123 : value`         -> `  test123`
#   `  test123 # test : value`  -> `  test123`
#   `  #test123 : value`        -> ``
#
function yq_get_key_line_text()
{
  local line_text="$1"

  RETURN_VALUE="${line_text%%:[$'\t' ]*}" # cut off text after `: `
  RETURN_VALUE="${RETURN_VALUE%%#*}"      # cut off text after `#`

  # trim tail white spaces
  gh_trim_trailing_white_space_chars "$RETURN_VALUE"
}

function yq_patch_diff_pause()
{
  if (( ENABLE_YAML_PATCH_DIFF_PAUSE_MODE )); then
    tkl_pause
  fi
}

function yq_patch()
{
  if [[ -z "$TEMP_DIR" || ! -d "$TEMP_DIR" ]]; then
    echo "$0: error: \`TEMP_DIR\` directory must be defined and exist: \`$TEMP_DIR\`." >&2
    return 255
  fi

  local input_yaml_edited_file="$1"
  local input_diff_file="$2"
  local temp_yaml_file="$3"
  local inout_yaml_file="$4"
  local input_yaml_file="${4:-"$inout_yaml_file"}" # if empty, then output yaml is used as input yaml to generate diff to print

  local last_error=0

  local temp_yaml_file_name="${temp_yaml_file##*/}"

  "${YQ_PATCH_DIFF_CMDLINE[@]}" -o "$temp_yaml_file" -i "$input_diff_file" "$input_yaml_edited_file" \
    > "$TEMP_DIR/${temp_yaml_file_name}.patch.stdout.log" 2> "$TEMP_DIR/${temp_yaml_file_name}.patch.stderr.log"
  last_error=$?

  if (( ! last_error )); then
    if (( ENABLE_YAML_DIFF_PRINT_BEFORE_PATCH )); then # technically - after patch, logically - before patched file output rewrite
      yq_diff_impl "$input_yaml_file" "$temp_yaml_file" "$TEMP_DIR/${temp_yaml_file_name}.diff" || return 255
      yq_print_file "$TEMP_DIR/${temp_yaml_file_name}.diff"
    fi

    cat "$TEMP_DIR/${temp_yaml_file_name}.patch.stderr.log"
    cat "$TEMP_DIR/${temp_yaml_file_name}.patch.stdout.log"

    if (( ENABLE_YAML_PRINT_AFTER_PATCH )); then
      yq_print_file "$temp_yaml_file"
    fi

    yq_patch_diff_pause

    mv -Tf "$temp_yaml_file" "$inout_yaml_file"

    return $?
  fi

  cat "$TEMP_DIR/${temp_yaml_file_name}.patch.stderr.log"
  cat "$TEMP_DIR/${temp_yaml_file_name}.patch.stdout.log"

  yq_patch_diff_pause

  return $last_error
}

tkl_register_call gh yq_init

tkl_set_return
