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
#     * ENABLE_YAML_PRINT_AFTER_PATCH               # has priority over `ENABLE_YAML_PRINT_AFTER_EDIT` variable
#     * ENABLE_YAML_DIFF_PRINT_AFTER_EDIT
#     * ENABLE_YAML_DIFF_PRINT_BEFORE_PATCH         # has priority over `ENABLE_YAML_DIFF_PRINT_AFTER_EDIT` variable
#     * ENABLE_YAML_PATCH_DIFF_PAUSE_MODE
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


function yq_init()
{
  which yq > /dev/null || return $?

  local yq_help="$(yq --help)"

  # CAUTION:
  #   Array instead of string is required here for correct expansion!
  #
  if grep 'https://github.com/mikefarah/yq[/ ]' - <<< "$yq_help" >/dev/null; then
    YQ_CMDLINE_READ=(yq)
    YQ_CMDLINE_READ_AS_YAML=(yq)
    YQ_CMDLINE_WRITE=(yq e)
    YQ_DIFF_ALL_CMDLINE=(diff -U0 -ad --horizon-lines=0 --suppress-common-lines)
    YQ_DIFF_NO_BLANKS_CMDLINE=(diff -U0 -aBd --horizon-lines=0 --suppress-common-lines)
    YQ_PATCH_DIFF_CMDLINE=(patch -Nt --merge)
  elif grep 'https://github.com/kislyuk/yq[/ ]' - <<< "$yq_help" >/dev/null; then
    YQ_CMDLINE_READ=(yq -cr)
    YQ_CMDLINE_READ_AS_YAML=(yq -ycr)
    YQ_CMDLINE_WRITE=(yq -y)
    YQ_DIFF_ALL_CMDLINE=(diff -U0 -ad --horizon-lines=0 --suppress-common-lines)
    YQ_DIFF_NO_BLANKS_CMDLINE=(diff -U0 -aBd --horizon-lines=0 --suppress-common-lines)
    YQ_PATCH_DIFF_CMDLINE=(patch -Nt --merge)
  else
    YQ_CMDLINE_READ=(yq)
    YQ_CMDLINE_READ_AS_YAML=(yq)
    YQ_CMDLINE_WRITE=(yq)
    YQ_DIFF_ALL_CMDLINE=(diff -U0 -ad --horizon-lines=0 --suppress-common-lines)
    YQ_DIFF_NO_BLANKS_CMDLINE=(diff -U0 -aBd --horizon-lines=0 --suppress-common-lines)
    YQ_PATCH_DIFF_CMDLINE=(patch -Nt --merge)
    echo "$0: error: \`yq\` implementation is not known." >&2
    return 255
  fi

  [[ -z "$ENABLE_YAML_PRINT_AFTER_EDIT" ]] && ENABLE_YAML_PRINT_AFTER_EDIT=0
  [[ -z "$ENABLE_YAML_PRINT_AFTER_PATCH" ]] && ENABLE_YAML_PRINT_AFTER_PATCH=0
  [[ -z "$ENABLE_YAML_DIFF_PRINT_AFTER_EDIT" ]] && ENABLE_YAML_DIFF_PRINT_AFTER_EDIT=0
  [[ -z "$ENABLE_YAML_DIFF_PRINT_BEFORE_PATCH" ]] && ENABLE_YAML_DIFF_PRINT_BEFORE_PATCH=0

  return 0
}

yq_init || exit $?


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
    if (( ENABLE_YAML_PRINT_AFTER_EDIT && ! ENABLE_YAML_PRINT_AFTER_PATCH )); then
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
      if (( ENABLE_YAML_PRINT_AFTER_EDIT && ! ENABLE_YAML_PRINT_AFTER_PATCH )); then
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
      if (( ENABLE_YAML_PRINT_AFTER_EDIT && ! ENABLE_YAML_PRINT_AFTER_PATCH )); then
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

  if (( ENABLE_YAML_DIFF_PRINT_AFTER_EDIT && ! ENABLE_YAML_DIFF_PRINT_BEFORE_PATCH )); then
    yq_print_file "$output_diff_file"
  fi

  return $last_error
}

# Does convert all chunks with at least one `remove` line into separate chunks
# with sequence of white space lines.
#
function yq_reduce_formatted_uniform_diff() # NOTE: Exists for tests ONLY
{
  local input_file_diff="$1"
  local output_file_reduced_diff="$2"

  local DiffLine
  local DiffLineFiltered
  local AccumDiffChunkLines
  local AccumDiffChunkLinesIndex
  local AddumDiffChunkLinesOffsetShift
  local RemoveLineOffset
  local RemoveLineOffsetShifted
  local NumRemoveLines
  local AddLineOffset
  local AddLineOffsetShifted
  local NumAddLines
  local AccumDiffChunkBody
  local IgnoreDiffChunk

  local IFS

  diff_load_file_to_arr "$input_file_diff" AccumDiffChunkLines 1 || return 255

  AccumDiffChunkLinesIndex=0
  AddumDiffChunkLinesOffsetShift=0
  AddLineOffsetShifted=0

  while (( AccumDiffChunkLinesIndex < ${#AccumDiffChunkLines[@]} )); do
    IgnoreDiffChunk=0

    diff_read_next_uniform_chunk_from_arr AccumDiffChunkLines AccumDiffChunkLinesIndex || return 255

    RemoveLineOffset="${RETURN_VALUES[0]}"
    NumRemoveLines="${RETURN_VALUES[1]}"
    AddLineOffset="${RETURN_VALUES[2]}"
    NumAddLines="${RETURN_VALUES[3]}"

    AccumDiffChunkBody="$RETURN_VALUE"

    {
      while IFS='' read -r DiffLine; do # enables read whole string line into a single variable
        DiffLineFiltered="${DiffLine%$'\r'}"
        # remove all white spaces
        DiffLineFiltered="${DiffLineFiltered//$'\t'/}"
        DiffLineFiltered="${DiffLineFiltered// /}"

        if [[ "${DiffLineFiltered:0:1}" == "-" ]]; then
          IgnoreDiffChunk=1
        elif (( IgnoreDiffChunk )) && [[ "$DiffLineFiltered" == "+" ]]; then
          (( AddumDiffChunkLinesOffsetShift-- ))
        fi
      done
    } <<< "$AccumDiffChunkBody" || return 255

    if (( ! IgnoreDiffChunk )); then
      (( AddLineOffsetShifted = AddLineOffset + AddumDiffChunkLinesOffsetShift ))

      diff_make_uniform_chunk_header "$RemoveLineOffset" "$NumRemoveLines" "$AddLineOffsetShifted" "$NumAddLines"

      echo -n "$RETURN_VALUE"$'\n'"$AccumDiffChunkBody"
    fi
  done > "$output_file_reduced_diff" || return 255

  return 0
}

# Does remove all empty `remove` lines from chunks with at least one `add` line.
# Does merge almost equal `remove` and `add` lines in all chunks to save line end comments.
#
function yq_reduce_edited_uniform_diff() # NOTE: Exists for tests ONLY
{
  local input_file_diff="$1"
  local output_file_reduced_diff="$2"

  local DiffLine
  local DiffLineFiltered
  local IsChunksStarted=0
  local AccumDiffChunk

  local IFS

  {
    while IFS='' read -r DiffLine; do # enables read whole string line into a single variable
      DiffLineFiltered="${DiffLine%$'\r'}"

      DiffLineFiltered="${DiffLineFiltered%%#%%*}" # remove `#%% ...` suffix

      # trim tail white spaces
      gh_trim_trailing_white_space_chars "$DiffLineFiltered"
      DiffLineFiltered="$RETURN_VALUE"

      if [[ "${DiffLineFiltered:0:2}" == "@@" && "${DiffLineFiltered: -2}" == "@@" ]]; then
        IsChunksStarted=1
        if [[ -n "$AccumDiffChunk" ]]; then
          yq_reduce_edited_uniform_diff_chunk "$AccumDiffChunk" || return 255
          echo -n "$RETURN_VALUE"
          AccumDiffChunk=''
        fi

        AccumDiffChunk="$AccumDiffChunk$DiffLine"$'\n'
      elif (( IsChunksStarted )) && [[ "${DiffLineFiltered:0:1}" == "-" || "${DiffLineFiltered:0:1}" == "+" ]]; then
        AccumDiffChunk="$AccumDiffChunk$DiffLine"$'\n'
      fi
    done

    if [[ -n "$AccumDiffChunk" ]]; then
      yq_reduce_edited_uniform_diff_chunk "$AccumDiffChunk" || return 255
      echo -n "$RETURN_VALUE"
    fi
  } < "$input_file_diff" > "$output_file_reduced_diff" || return 255

  return 0
}

function yq_reduce_edited_uniform_diff_chunk() # NOTE: Exists for tests ONLY
{
  local input_diff_chunk="$1"

  RETURN_VALUE=''

  local DiffLine
  local DiffLineFiltered
  local AccumDiffChunkLines
  local AccumDiffChunkLinesIndex
  local AccumDiffRemoveChunk
  local AccumDiffAddChunkLines
  local AccumDiffAddChunkLinesIndex
  local HasAccumDiffChunkAddLines
  local i

  local IFS

  diff_load_string_to_arr "$input_diff_chunk" AccumDiffChunkLines 1 || return 255

  # load addition lines only from edited difference file chunk

  HasAccumDiffChunkAddLines=0
  AccumDiffAddChunkLines=()
  AccumDiffAddChunkLinesIndex=0

  for (( i=0; i < ${#AccumDiffChunkLines[@]}; i++ )); do
    DiffLine="${AccumDiffChunkLines[i]}"

    DiffLineFiltered="${DiffLine%$'\r'}"

    if [[ "${DiffLineFiltered:0:1}" == "+" ]]; then
      HasAccumDiffChunkAddLines=1
      AccumDiffAddChunkLines[AccumDiffAddChunkLinesIndex++]="$DiffLine"
    fi
  done

  # remove all white space `remove` lines from chunks with at least one `add` line

  AccumDiffChunkLinesIndex=0

  diff_read_next_uniform_chunk_from_arr AccumDiffChunkLines AccumDiffChunkLinesIndex || return 255

  local RemoveLineOffset="${RETURN_VALUES[0]}"
  local NumRemoveLines="${RETURN_VALUES[1]}"
  local AddLineOffset="${RETURN_VALUES[2]}"
  local NumAddLines="${RETURN_VALUES[3]}"

  local AccumDiffChunkBody="$RETURN_VALUE"
  local AccumDiffChunkBodyIndex=0

  {
    while IFS='' read -r DiffLine; do # enables read whole string line into a single variable
      DiffLineFiltered="${DiffLine%$'\r'}"
      # remove all white spaces
      DiffLineFiltered="${DiffLineFiltered//$'\t'/}"
      DiffLineFiltered="${DiffLineFiltered// /}"

      if [[ "${DiffLineFiltered:0:1}" == "-" ]]; then
        if [[ "$DiffLineFiltered" == "-" ]]; then
          if (( ! AccumDiffChunkBodyIndex )); then
            (( RemoveLineOffset++ )) # TODO: still inaccurate
          fi
          if (( HasAccumDiffChunkAddLines )); then
            if (( NumRemoveLines > 0 )); then
              (( NumRemoveLines-- ))
            fi
          else
            AccumDiffRemoveChunk="$AccumDiffRemoveChunk$DiffLine"$'\n'
          fi
        else
          AccumDiffRemoveChunk="$AccumDiffRemoveChunk$DiffLine"$'\n'

          (( AccumDiffChunkBodyIndex++ ))
        fi
      else
        break
      fi
    done
  } <<< "$AccumDiffChunkBody" || return 255

  # Save offsets delta after white space lines remove but before chunk remove
  # and addition lines merge to pass it to the merge algorithm of 2 diffs.
  #
  local MergeDiffLinesOffsetShift

  (( MergeDiffLinesOffsetShift = NumAddLines - NumRemoveLines ))

  # merge almost equal `remove` and `add` lines in all chunks to save line end comments

  local MergedDiffRemoveChunk
  local MergedDiffAddChunk
  local MergedDiffLineLen
  local DiffAddLine
  local DiffAddLineFiltered

  local DiffLineFilteredLen
  local DiffAddLineFilteredLen

  if (( HasAccumDiffChunkAddLines )); then
    i=0

    {
      while IFS='' read -r DiffLine; do # enables read whole string line into a single variable
        DiffLineFiltered="${DiffLine%$'\r'}"

        DiffLineFiltered="${DiffLineFiltered%%#%%*}" # remove `#%% ...` suffix

        # trim tail white spaces
        gh_trim_trailing_white_space_chars "$DiffLineFiltered"
        DiffLineFiltered="$RETURN_VALUE"

        if [[ "${DiffLineFiltered:0:2}" == "@@" && "${DiffLineFiltered: -2}" == "@@" ]]; then
          :
        elif [[ "${DiffLineFiltered:0:1}" == "-" ]]; then
          if (( i < ${#AccumDiffAddChunkLines[@]} )); then
            DiffAddLine="${AccumDiffAddChunkLines[i++]}"

            DiffAddLineFiltered="${DiffAddLine%$'\r'}"

            (( DiffLineFilteredLen = ${#DiffLineFiltered} ))
            (( DiffAddLineFilteredLen = ${#DiffAddLineFiltered} ))

            if (( DiffAddLineFilteredLen < DiffLineFilteredLen )); then
              (( MergedDiffLineLen = DiffAddLineFilteredLen ))
            else
              (( MergedDiffLineLen = DiffLineFilteredLen ))
            fi
            if (( MergedDiffLineLen > 0 )); then # just in case
              (( MergedDiffLineLen-- ))
            fi

            if (( DiffAddLineFilteredLen >= DiffLineFilteredLen )) || \
               [[ "${DiffLineFiltered:1:MergedDiffLineLen}" != "${DiffAddLineFiltered:1:MergedDiffLineLen}" ]]; then
              MergedDiffRemoveChunk="$MergedDiffRemoveChunk-${DiffAddLine:1}"$'\n'
              MergedDiffAddChunk="$MergedDiffAddChunk$DiffAddLine"$'\n'
            else
              MergedDiffRemoveChunk="$MergedDiffRemoveChunk-${DiffAddLine:1}"$'\n'
              MergedDiffAddChunk="$MergedDiffAddChunk+${DiffLine:1}"$'\n'
            fi
          else
            #MergedDiffRemoveChunk="$MergedDiffRemoveChunk$DiffLine"$'\n'
            break
          fi
        else
          break
        fi
      done
    } <<< "$AccumDiffRemoveChunk" || return 255

    # read the rest

    for (( ; i < ${#AccumDiffAddChunkLines[@]}; i++ )); do
      DiffAddLine="${AccumDiffAddChunkLines[i]}"

      (( NumRemoveLines++ ))

      MergedDiffRemoveChunk="$MergedDiffRemoveChunk-${DiffAddLine:1}"$'\n'
      MergedDiffAddChunk="$MergedDiffAddChunk+${DiffAddLine:1}"$'\n'
    done
  else
    MergedDiffRemoveChunk="$AccumDiffRemoveChunk"
  fi

  # update diff chunk offset params
  diff_make_uniform_chunk_header "$RemoveLineOffset" "$NumRemoveLines" "$AddLineOffset" "$NumAddLines" "$MergeDiffLinesOffsetShift"

  RETURN_VALUE="$RETURN_VALUE"$'\n'"$MergedDiffRemoveChunk$MergedDiffAddChunk"

  return 0
}

# Does merge the formatted-reduced and the edited-reduced difference files removing
# all inversed chunks from edited-reduced, when all lines from an edited-reduced
# chunk are equal to all lines from an formatted-reduced chunk except the line
# operation is a remove.
#
function yq_merge_formatted_and_edited_uniform_diffs() # NOTE: Exists for tests ONLY
{
  local input_file_formatted_reduced_diff="$1"
  local input_file_edited_reduced_diff="$2"
  local output_file_merged_edited_formatted_diff="$3"

  local FormattedDiffLine
  local FormattedDiffLineFiltered
  local FormattedDiffLines
  local FormattedDiffLinesIndex
  local FormattedDiffLinesOffsetShift
  local FormattedDiffRemoveLineOffset
  local FormattedDiffRemoveLineOffsetShifted
  local FormattedDiffNumRemoveLines
  local FormattedDiffAddLineOffset
  local FormattedDiffAddLineOffsetShifted
  local FormattedDiffNumAddLines
  local FormattedDiffChunkBody
  local FormattedDiffChunkBodyFiltered

  local EditedDiffLine
  local EditedDiffLineFiltered
  local EditedDiffLines
  local EditedDiffLinesIndex
  local EditedDiffLinesOffsetShift
  local EditedDiffRemoveLineOffset
  local EditedDiffRemoveLineOffsetShifted
  local EditedDiffNumRemoveLines
  local EditedDiffAddLineOffset
  #local EditedDiffAddLineOffsetShifted
  local EditedDiffNumAddLines
  local EditedDiffOffsetShift
  local EditedDiffChunkBody
  local EditedDiffChunkBodyFiltered

  local HasFormattedDiffChunk
  local HasEditedDiffChunk

  local i
  local j

  local IFS

  diff_load_file_to_arr "$input_file_formatted_reduced_diff" FormattedDiffLines 1 || return 255
  diff_load_file_to_arr "$input_file_edited_reduced_diff" EditedDiffLines 1 || return 255

  FormattedDiffLinesIndex=0
  FormattedDiffLinesOffsetShift=0
  EditedDiffLinesIndex=0
  EditedDiffLinesOffsetShift=0

  HasFormattedDiffChunk=0
  HasEditedDiffChunk=0

  if (( FormattedDiffLinesIndex < ${#FormattedDiffLines[@]} )); then
    HasFormattedDiffChunk=1

    diff_read_next_uniform_chunk_from_arr FormattedDiffLines FormattedDiffLinesIndex || return 255

    FormattedDiffRemoveLineOffset="${RETURN_VALUES[0]}"
    FormattedDiffNumRemoveLines="${RETURN_VALUES[1]}"
    FormattedDiffAddLineOffset="${RETURN_VALUES[2]}"
    FormattedDiffNumAddLines="${RETURN_VALUES[3]}"

    FormattedDiffChunkBody="$RETURN_VALUE"
  fi || return 255

  if (( EditedDiffLinesIndex < ${#EditedDiffLines[@]} )); then
    HasEditedDiffChunk=1

    diff_read_next_uniform_chunk_from_arr EditedDiffLines EditedDiffLinesIndex || return 255

    EditedDiffRemoveLineOffset="${RETURN_VALUES[0]}"
    EditedDiffNumRemoveLines="${RETURN_VALUES[1]}"
    EditedDiffAddLineOffset="${RETURN_VALUES[2]}"
    EditedDiffNumAddLines="${RETURN_VALUES[3]}"
    EditedDiffOffsetShift="${RETURN_VALUES[4]-0}"

    EditedDiffChunkBody="$RETURN_VALUE"
  fi || return 255

  while (( HasFormattedDiffChunk || HasEditedDiffChunk )); do
    # chunk offsets shift
    (( FormattedDiffRemoveLineOffsetShifted = FormattedDiffRemoveLineOffset + FormattedDiffLinesOffsetShift ))
    (( FormattedDiffAddLineOffsetShifted = FormattedDiffAddLineOffset + FormattedDiffLinesOffsetShift ))
    (( EditedDiffRemoveLineOffsetShifted = EditedDiffRemoveLineOffset + EditedDiffLinesOffsetShift ))
    #(( EditedDiffAddLineOffsetShifted = EditedDiffAddLineOffset + EditedDiffLinesOffsetShift ))

    if (( HasFormattedDiffChunk && (HasEditedDiffChunk && FormattedDiffRemoveLineOffsetShifted < EditedDiffAddLineOffset || ! HasEditedDiffChunk) )); then
      # update diff chunk offset params
      diff_make_uniform_chunk_header "$FormattedDiffRemoveLineOffsetShifted" "$FormattedDiffNumRemoveLines" "$FormattedDiffAddLineOffsetShifted" "$FormattedDiffNumAddLines"

      echo -n "$RETURN_VALUE"$'\n'"$FormattedDiffChunkBody"

      if (( FormattedDiffLinesIndex < ${#FormattedDiffLines[@]} )); then
        diff_read_next_uniform_chunk_from_arr FormattedDiffLines FormattedDiffLinesIndex || return 255

        FormattedDiffRemoveLineOffset="${RETURN_VALUES[0]}"
        FormattedDiffNumRemoveLines="${RETURN_VALUES[1]}"
        FormattedDiffAddLineOffset="${RETURN_VALUES[2]}"
        FormattedDiffNumAddLines="${RETURN_VALUES[3]}"

        FormattedDiffChunkBody="$RETURN_VALUE"
      else
        HasFormattedDiffChunk=0
      fi
    elif (( HasFormattedDiffChunk && HasEditedDiffChunk && FormattedDiffRemoveLineOffsetShifted == EditedDiffAddLineOffset )); then
      # update diff chunk offset params
      diff_make_uniform_chunk_header "$FormattedDiffRemoveLineOffsetShifted" "$FormattedDiffNumRemoveLines" "$FormattedDiffAddLineOffsetShifted" "$FormattedDiffNumAddLines"

      echo -n "$RETURN_VALUE"$'\n'"$FormattedDiffChunkBody"

      FormattedDiffChunkBodyFiltered=''
      EditedDiffChunkBodyFiltered=''

      while IFS='' read -r FormattedDiffLine; do # enables read whole string line into a single variable
        FormattedDiffChunkBodyFiltered="$FormattedDiffChunkBodyFiltered${FormattedDiffLine:1}"$'\n'
      done <<< "$FormattedDiffChunkBody" || return 255

      while IFS='' read -r EditedDiffLine; do # enables read whole string line into a single variable
        EditedDiffChunkBodyFiltered="$EditedDiffChunkBodyFiltered${EditedDiffLine:1}"$'\n'
      done <<< "$EditedDiffChunkBody" || return 255

      if [[ "$FormattedDiffChunkBodyFiltered" != "$EditedDiffChunkBodyFiltered" ]]; then
        # update diff chunk offset params
        diff_make_uniform_chunk_header "$EditedDiffAddLineOffset" "$EditedDiffNumRemoveLines" "$EditedDiffRemoveLineOffsetShifted" "$EditedDiffNumAddLines" "$EditedDiffOffsetShift"

        echo -n "$RETURN_VALUE"$'\n'"$EditedDiffChunkBody"

        # increase next formatted diff chunk offset shift
        if (( ! EditedDiffOffsetShift )); then
          (( FormattedDiffLinesOffsetShift += EditedDiffNumAddLines - EditedDiffNumRemoveLines ))
          (( EditedDiffLinesOffsetShift += EditedDiffNumAddLines - EditedDiffNumRemoveLines ))
        else
          (( FormattedDiffLinesOffsetShift += EditedDiffOffsetShift ))
          (( EditedDiffLinesOffsetShift += EditedDiffOffsetShift ))
        fi
      fi

      if (( FormattedDiffLinesIndex < ${#FormattedDiffLines[@]} )); then
        diff_read_next_uniform_chunk_from_arr FormattedDiffLines FormattedDiffLinesIndex || return 255

        FormattedDiffRemoveLineOffset="${RETURN_VALUES[0]}"
        FormattedDiffNumRemoveLines="${RETURN_VALUES[1]}"
        FormattedDiffAddLineOffset="${RETURN_VALUES[2]}"
        FormattedDiffNumAddLines="${RETURN_VALUES[3]}"

        FormattedDiffChunkBody="$RETURN_VALUE"
      else
        HasFormattedDiffChunk=0
      fi

      if (( EditedDiffLinesIndex < ${#EditedDiffLines[@]} )); then
        diff_read_next_uniform_chunk_from_arr EditedDiffLines EditedDiffLinesIndex || return 255

        EditedDiffRemoveLineOffset="${RETURN_VALUES[0]}"
        EditedDiffNumRemoveLines="${RETURN_VALUES[1]}"
        EditedDiffAddLineOffset="${RETURN_VALUES[2]}"
        EditedDiffNumAddLines="${RETURN_VALUES[3]}"
        EditedDiffOffsetShift="${RETURN_VALUES[4]-0}"

        EditedDiffChunkBody="$RETURN_VALUE"
      else
        HasEditedDiffChunk=0
      fi
    elif (( HasEditedDiffChunk && (HasFormattedDiffChunk && FormattedDiffRemoveLineOffsetShifted > EditedDiffAddLineOffset || ! HasFormattedDiffChunk) )); then
      diff_make_uniform_chunk_header "$EditedDiffAddLineOffset" "$EditedDiffNumRemoveLines" "$EditedDiffRemoveLineOffsetShifted" "$EditedDiffNumAddLines" "$EditedDiffOffsetShift"

      echo -n "$RETURN_VALUE"$'\n'"$EditedDiffChunkBody"

      # increase next formatted diff chunk offset shift
      if (( ! EditedDiffOffsetShift )); then
        (( FormattedDiffLinesOffsetShift += EditedDiffNumAddLines - EditedDiffNumRemoveLines ))
        (( EditedDiffLinesOffsetShift += EditedDiffNumAddLines - EditedDiffNumRemoveLines ))
      else
        (( FormattedDiffLinesOffsetShift += EditedDiffOffsetShift ))
        (( EditedDiffLinesOffsetShift += EditedDiffOffsetShift ))
      fi

      if (( EditedDiffLinesIndex < ${#EditedDiffLines[@]} )); then
        diff_read_next_uniform_chunk_from_arr EditedDiffLines EditedDiffLinesIndex || return 255

        EditedDiffRemoveLineOffset="${RETURN_VALUES[0]}"
        EditedDiffNumRemoveLines="${RETURN_VALUES[1]}"
        EditedDiffAddLineOffset="${RETURN_VALUES[2]}"
        EditedDiffNumAddLines="${RETURN_VALUES[3]}"
        EditedDiffOffsetShift="${RETURN_VALUES[4]-0}"

        EditedDiffChunkBody="$RETURN_VALUE"
      else
        HasEditedDiffChunk=0
      fi
    fi
  done > "$output_file_merged_edited_formatted_diff" || return 255

  return 0
}

# Restores blank lines and comments.
#
# PROs:
#   * Can restore blank lines together with standalone comment lines: `  # ... `
#   * Can restore line end comments: `  key: value # ...`
#   * Can detect a line remove/change/add altogether.
#
# CONs:
#   * Because of has having a guess logic, may leave artefacts or invalid corrections.
#   * Does not restore line end comments, where the yaml data is changed.
#
function yq_restore_edited_uniform_diff() # NOTE: Experimental
{
  local input_file_edited_diff="$1"
  local output_file_restored_diff="$2"

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
        DiffRemoveChunkLineBlanked="${DiffRemoveChunkLineFiltered//$'\t'/}"
        DiffRemoveChunkLineBlanked="${DiffRemoveChunkLineBlanked// /}"

        if [[ -z "$DiffRemoveChunkLineBlanked" ]]; then
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

tkl_set_return
