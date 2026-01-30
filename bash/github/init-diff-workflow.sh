#!/bin/bash

# Script both for execution and inclusion.
[[ -z "$BASH" || (-n "$SOURCE_GHWF_INIT_DIFF_WORKFLOW_SH" && SOURCE_GHWF_INIT_DIFF_WORKFLOW_SH -ne 0) ]] && return

SOURCE_GHWF_INIT_DIFF_WORKFLOW_SH=1 # including guard

if [[ -z "$GH_WORKFLOW_ROOT" ]]; then
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
fi

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?

tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-basic-workflow.sh"


function diff_init()
{
  ! tkl_is_call_registered gh diff_init || return 255

  echo "${FUNCNAME[0]}:"

  # always print the path and version of all tools to compare it between pipeline runs

  if ! gh_call which diff; then
    echo "${FUNCNAME[0]}: \`diff\` is not found."
    return 255
  fi

  gh_call diff --version

  if ! gh_call which patch; then
    echo "${FUNCNAME[0]}: \`patch\` is not found."
    return 255
  fi

  gh_call patch --version

  return 0
}

function diff_load_file_to_arr()
{
  local input_file_diff="$1"
  local output_arr_var="$2"
  local read_chunks_only="${3:-0}"

  local DiffLine
  local DiffLinesIndex
  local DiffLineFiltered
  local IsChunksStarted=0

  local IFS

  {
    tkl_declare_array $output_arr_var

    DiffLinesIndex=0

    if (( read_chunks_only )); then
      while IFS='' read -r DiffLine; do # enables read whole string line into a single variable
        DiffLineFiltered="${DiffLine%$'\r'}"

        DiffLineFiltered="${DiffLineFiltered%%#%%*}" # cut off `#%% ...` suffix

        # trim tail white spaces
        gh_trim_trailing_white_space_chars "$DiffLineFiltered"
        DiffLineFiltered="$RETURN_VALUE"

        if [[ "${DiffLineFiltered:0:2}" == "@@" && "${DiffLineFiltered: -2}" == "@@" ]]; then
          IsChunksStarted=1
          tkl_declare $output_arr_var[DiffLinesIndex++] "$DiffLine"
        elif (( IsChunksStarted )) && [[ "${DiffLineFiltered:0:1}" == "-" || "${DiffLineFiltered:0:1}" == "+" ]]; then
          tkl_declare $output_arr_var[DiffLinesIndex++] "$DiffLine"
        fi
      done
    else
      while IFS='' read -r DiffLine; do # enables read whole string line into a single variable
        tkl_declare $output_arr_var[DiffLinesIndex++] "$DiffLine"
      done
    fi
  } < "$input_file_diff" || return 255

  return 0
}

function diff_load_string_to_arr()
{
  local input_str_diff="$1"
  local output_arr_var="$2"
  local read_chunks_only="${3:-0}"

  local DiffLine
  local DiffLinesIndex
  local DiffLineFiltered
  local IsChunksStarted=0

  local IFS

  {
    tkl_declare_array $output_arr_var

    DiffLinesIndex=0

    if (( read_chunks_only )); then
      while IFS='' read -r DiffLine; do # enables read whole string line into a single variable
        DiffLineFiltered="${DiffLine%$'\r'}"

        DiffLineFiltered="${DiffLineFiltered%%#%%*}" # cut off `#%% ...` suffix

        # trim tail white spaces
        gh_trim_trailing_white_space_chars "$DiffLineFiltered"
        DiffLineFiltered="$RETURN_VALUE"

        if [[ "${DiffLineFiltered:0:2}" == "@@" && "${DiffLineFiltered: -2}" == "@@" ]]; then
          IsChunksStarted=1
          tkl_declare $output_arr_var[DiffLinesIndex++] "$DiffLine"
        elif (( IsChunksStarted )) && [[ "${DiffLineFiltered:0:1}" == "-" || "${DiffLineFiltered:0:1}" == "+" ]]; then
          tkl_declare $output_arr_var[DiffLinesIndex++] "$DiffLine"
        fi
      done
    else
      while IFS='' read -r DiffLine; do # enables read whole string line into a single variable
        tkl_declare $output_arr_var[DiffLinesIndex++] "$DiffLine"
      done
    fi
  } <<< "$input_str_diff" || return 255

  return 0
}

function diff_read_next_uniform_chunk_from_arr()
{
  local diff_lines_var="$1"
  local diff_line_index_var="$2"
  local diff_chunk_remove_lines_var="$3"
  local diff_chunk_add_lines_var="$4"

  local num_diff_lines
  local diff_line_index

  local DiffChunkRemoveLinesIndex
  local DiffChunkAddLinesIndex

  local RemoveLineOffset
  local NumRemoveLines
  local AddLineOffset
  local NumAddLines
  local DiffLineOffsetShift

  local DiffLine
  local DiffLineFiltered
  local IsChunksStarted=0

  local IFS

  RETURN_VALUES=()  # @@ <0>,<1> <2>,<3> @@
  RETURN_VALUE=''   # chunk body

  tkl_declare_eval num_diff_lines "\${#$diff_lines_var[@]}"
  tkl_declare_eval diff_line_index "\$$diff_line_index_var"

  if [[ -n "$diff_chunk_remove_lines_var" ]]; then
    DiffChunkRemoveLinesIndex=0
    tkl_declare_array "$diff_chunk_remove_lines_var"
  fi
  if [[ -n "$diff_chunk_add_lines_var" ]]; then
    DiffChunkAddLinesIndex=0
    tkl_declare_array "$diff_chunk_add_lines_var"
  fi

  local i

  for (( i=diff_line_index; i < num_diff_lines; i++ )); do
    #echo $i >&2
    tkl_declare_eval DiffLine "\${$diff_lines_var[i]}"

    DiffLineFiltered="${DiffLine%$'\r'}"

    if diff_read_uniform_chunk_header "$DiffLineFiltered"; then
      if (( IsChunksStarted )); then
        #echo break >&2
        break
      fi

      #echo header >&2
      IsChunksStarted=1

      RemoveLineOffset="${RETURN_VALUES[0]}"
      NumRemoveLines="${RETURN_VALUES[1]}"
      AddLineOffset="${RETURN_VALUES[2]}"
      NumAddLines="${RETURN_VALUES[3]}"
      DiffLineOffsetShift="${RETURN_VALUES[4]-0}"

      #RETURN_VALUE="$RETURN_VALUE$DiffLine"$'\n'
    elif (( IsChunksStarted )); then
      #echo "$DiffLine" >&2
      if [[ "${DiffLineFiltered:0:1}" == "-" ]]; then
        if [[ -n "$diff_chunk_remove_lines_var" ]]; then
          tkl_declare $diff_chunk_remove_lines_var[DiffChunkRemoveLinesIndex++] "${DiffLine:1}"
        else
          RETURN_VALUE="$RETURN_VALUE$DiffLine"$'\n'
        fi
      elif [[ "${DiffLineFiltered:0:1}" == "+" ]]; then
        if [[ -n "$diff_chunk_add_lines_var" ]]; then
          tkl_declare $diff_chunk_add_lines_var[DiffChunkAddLinesIndex++] "${DiffLine:1}"
        else
          RETURN_VALUE="$RETURN_VALUE$DiffLine"$'\n'
        fi
      fi
    fi
  done || return 255

  RETURN_VALUES=("$RemoveLineOffset" "$NumRemoveLines" "$AddLineOffset" "$NumAddLines" "$DiffLineOffsetShift")

  tkl_declare $diff_line_index_var "$i"
  #echo save=$i >&2

  return 0
}

function diff_read_uniform_chunk_header()
{
  local diff_line="$1"

  local IFS

  RETURN_VALUES=()

  local RemoveLineParams
  local AddLineParams
  local RemoveLineOffset
  local NumRemoveLines
  local AddLineOffset
  local NumAddLines

  local DiffLineFiltered="${diff_line%$'\r'}"

  # read saved values after `#%%` characters
  local DiffLineOffsetShift

  if [[ "${DiffLineFiltered#*#%%}" != "$DiffLineFiltered" ]]; then
    DiffLineOffsetShift="${DiffLineFiltered#*#%%}"

    # trim head white spaces
    gh_trim_leading_white_space_chars "$DiffLineOffsetShift"

    # trim tail white spaces
    gh_trim_trailing_white_space_chars "$RETURN_VALUE"
    DiffLineOffsetShift="$RETURN_VALUE"

    (( DiffLineOffsetShift = DiffLineOffsetShift )) # drop `+` prefix
  fi

  DiffLineFiltered="${DiffLineFiltered%%#%%*}" # cut off `#%% ...` suffix

  # trim tail white spaces
  gh_trim_trailing_white_space_chars "$DiffLineFiltered"
  DiffLineFiltered="$RETURN_VALUE"

  if [[ "${DiffLineFiltered:0:2}" == "@@" && "${DiffLineFiltered: -2}" == "@@" ]]; then
    DiffLineFiltered="${DiffLineFiltered:2:-2}"

    IFS=$' \t' read -r RemoveLineParams AddLineParams <<< "$DiffLineFiltered"
    IFS=',' read -r RemoveLineOffset NumRemoveLines <<< "$RemoveLineParams"
    IFS=',' read -r AddLineOffset NumAddLines <<< "$AddLineParams"

    # remove `-` and `+` prefixes
    (( RemoveLineOffset = -RemoveLineOffset ))
    (( AddLineOffset = AddLineOffset ))

    if [[ -z "$NumRemoveLines" ]]; then
      NumRemoveLines=1
    fi
    if [[ -z "$NumAddLines" ]]; then
      NumAddLines=1
    fi

    RETURN_VALUES=("$RemoveLineOffset" "$NumRemoveLines" "$AddLineOffset" "$NumAddLines" "$DiffLineOffsetShift")
  else
    return 255
  fi

  return 0
}

function diff_make_uniform_chunk_header()
{
  # @@ <0>,<1> <2>,<3> @@ [#%% <OffsetShift>]
  local RemoveLineOffset="$1"
  local NumRemoveLines="$2"
  local AddLineOffset="$3"
  local NumAddLines="$4"
  local OffsetShift="${5:-0}"

  local RemoveLineParams="-$RemoveLineOffset"
  if (( NumRemoveLines != 1 )); then
    RemoveLineParams="$RemoveLineParams,$NumRemoveLines"
  fi

  local AddLineParams="+$AddLineOffset"
  if (( NumAddLines != 1 )); then
    AddLineParams="$AddLineParams,$NumAddLines"
  fi

  RETURN_VALUE="@@ $RemoveLineParams $AddLineParams @@"

  if (( OffsetShift )); then
    if (( OffsetShift > 0 )); then
      OffsetShift="+$OffsetShift"
    fi
    RETURN_VALUE="$RETURN_VALUE #%% $OffsetShift"
  fi
}

tkl_register_call gh diff_init

tkl_set_return
