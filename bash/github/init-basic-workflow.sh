#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# NOTE:
#   Lower case variable names for a per script usage (input only).
#   Upper case variable names for use between scripts including return values.
#

# NOTE:
#   To be able to distinguish a pipeline service outage from the changes
#   absence including residual or algorithmically not actual changes you must
#   declare these variables:
#
#     * CONTINUE_ON_INVALID_INPUT=1
#     * CONTINUE_ON_EMPTY_CHANGES=1
#     * CONTINUE_ON_RESIDUAL_CHANGES=1
#
#   Because invalid input, empty or residual changes has to be detected and
#   has to be not trigger a commit, then we must to continue on them
#   explicitly.
#   Because empty changes does ignore by the VCS, then we must make additional
#   changes locally to be able to commit, so we create a changelog file with
#   local changes.
#   Additionally, the changelog file contains a timestamp for each script
#   execution altogether with several notices and warnings printed from the
#   script to highlight the pipeline events and basic statistic without a need
#   to compare a complete set of changes.
#
#   Other variables:
#
#     * ENABLE_GENERATE_CHANGELOG_FILE=1
#     * CHANGELOG_FILE=repo/owner-of-content/repo-with-content/content-changelog.txt
#     * ENABLE_PRINT_CURL_RESPONSE_ON_ERROR=1
#     * ENABLE_COMMIT_MESSAGE_DATE_WITH_TIME=1
#     * ENABLE_CHANGELOG_BUF_ARR_AUTO_SERIALIZE=1   # enabled by default
#     * ERROR_ON_EMPTY_CHANGES_WITHOUT_ERRORS=1
#

# Script both for execution and inclusion.
[[ -z "$BASH" || (-n "$SOURCE_GHWF_INIT_BASIC_WORKFLOW_SH" && SOURCE_GHWF_INIT_BASIC_WORKFLOW_SH -ne 0) ]] && return

SOURCE_GHWF_INIT_BASIC_WORKFLOW_SH=1 # including guard

if [[ -z "$GH_WORKFLOW_ROOT" ]]; then
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
fi

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?

tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-print-workflow.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-github-workflow.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/utils.sh"


function init_basic_workflow()
{
  # CAUTION:
  #   You must always load unconditionally all the `GITHUB_ENV` variables!
  #
  #   The reason is in the method of the bash script execution inside a
  #   GitHub Action step. While the GitHub Action loads the `GITHUB_ENV`
  #   variables only in the next step, the variables can be already dropped in
  #   the current step.
  #
  #   If a bash script inside GitHub Action step does not have a shebang line,
  #   then each line of it does run as a bash subprocess. This means that the
  #   all variables would be dropped after a subprocess exit. This function
  #   reloads the `GITHUB_ENV` on each such subprocess execution.
  #
  gh_eval_github_env

  # global variables init
  [[ -z "$CONTINUE_ON_INVALID_INPUT" ]] &&                gh_set_env_var CONTINUE_ON_INVALID_INPUT 0
  [[ -z "$CONTINUE_ON_EMPTY_CHANGES" ]] &&                gh_set_env_var CONTINUE_ON_EMPTY_CHANGES 0
  [[ -z "$CONTINUE_ON_RESIDUAL_CHANGES" ]] &&             gh_set_env_var CONTINUE_ON_RESIDUAL_CHANGES 0
  [[ -z "$ENABLE_GENERATE_CHANGELOG_FILE" ]] &&           gh_set_env_var ENABLE_GENERATE_CHANGELOG_FILE 0
  [[ -z "$ENABLE_PRINT_CURL_RESPONSE_ON_ERROR" ]] &&      gh_set_env_var ENABLE_PRINT_CURL_RESPONSE_ON_ERROR 0
  [[ -z "$ENABLE_COMMIT_MESSAGE_DATE_WITH_TIME" ]] &&     gh_set_env_var ENABLE_COMMIT_MESSAGE_DATE_WITH_TIME 0
  [[ -z "$ENABLE_CHANGELOG_BUF_ARR_AUTO_SERIALIZE" ]] &&  gh_set_env_var ENABLE_CHANGELOG_BUF_ARR_AUTO_SERIALIZE 1

  if (( ENABLE_GENERATE_CHANGELOG_FILE )); then
    [[ -z "$CHANGELOG_FILE" ]] && gh_set_env_var CHANGELOG_FILE 'changelog.txt'
  fi

  if (( ENABLE_CHANGELOG_BUF_ARR_AUTO_SERIALIZE )); then
    if [[ -z "${GHWF_CHANGELOG_BUF_KEY_SERIALIZED_ARR_STR+x}" ]]; then # to save buffer between workflow steps
      # associated array keys as buffer names
      gh_set_env_var GHWF_CHANGELOG_BUF_KEY_SERIALIZED_ARR_STR  ''
      tkl_declare_array GHWF_CHANGELOG_BUF_KEY_ARR
      # associated array values as buffer content
      gh_set_env_var GHWF_CHANGELOG_BUF_VALUE_SERIALIZED_ARR_STR  ''
      tkl_declare_array GHWF_CHANGELOG_BUF_VALUE_ARR
    fi
  else
    if [[ -z "${GHWF_CHANGELOG_BUF_KEY_ARR[@]+x}" ]]; then # to save buffer between workflow steps
      # associated array keys as buffer names
      tkl_declare_array GHWF_CHANGELOG_BUF_KEY_ARR
      # associated array values as buffer content
      tkl_declare_array GHWF_CHANGELOG_BUF_VALUE_ARR
    fi
  fi

  return 0
}

function gh_find_changelog_buf_arr_index_to_insert_from()
{
  RETURN_VALUE=0

  # [+]<name> | -<name>
  #   * [+]<name> - insert after <name>.
  #   * -<name>   - insert before <name>.
  #
  local changelog_msg_name_to_insert_from="$1"

  local insert_from_index=-1
  local changelog_buf_key_arr_len=${#GHWF_CHANGELOG_BUF_KEY_ARR[@]}

  local changelog_msg_name_to_insert_from_sign="${changelog_msg_name_to_insert_from:1}"
  local insert_from_after=1

  if [[ "$changelog_msg_name_to_insert_from_sign" == "-" ]]; then
    insert_from_after=0 # insert before
  fi

  if [[ -n "$changelog_msg_name_to_insert_from" ]]; then
    changelog_msg_name_to_insert_from="${changelog_msg_name_to_insert_from#-}"

    for (( i=0; i < changelog_buf_key_arr_len; i++ )); do
      if [[ "${GHWF_CHANGELOG_BUF_KEY_ARR[i]}" == "$changelog_msg_name_to_insert_from" ]]; then
        insert_from_index=i
        break
      fi
    done
  fi

  if (( insert_from_index == -1 )); then
    insert_from_index=$changelog_buf_key_arr_len
  elif (( insert_from_after )); then
    (( insert_from_index++ ))
  fi

  RETURN_VALUE=$insert_from_index
}

function gh_prepend_changelog_file()
{
  (( ! ENABLE_GENERATE_CHANGELOG_FILE )) && return 0
  if (( ENABLE_CHANGELOG_BUF_ARR_AUTO_SERIALIZE )); then
    [[ -n "$GHWF_CHANGELOG_BUF_KEY_SERIALIZED_ARR_STR" ]] || return 0
  else
    (( "${#GHWF_CHANGELOG_BUF_KEY_ARR[@]}" )) || return 0
  fi

  local changelog_buf=''
  local value

  if (( ENABLE_CHANGELOG_BUF_ARR_AUTO_SERIALIZE )); then
    tkl_deserialize_array "$GHWF_CHANGELOG_BUF_VALUE_SERIALIZED_ARR_STR" GHWF_CHANGELOG_BUF_VALUE_ARR
  fi

  for value in "${GHWF_CHANGELOG_BUF_VALUE_ARR[@]}"; do
    changelog_buf="$changelog_buf$value"$'\r\n'
  done

  if [[ -f "$CHANGELOG_FILE" && -s "$CHANGELOG_FILE" ]]; then
    changelog_buf="$changelog_buf"$'\r\n'"$(< "$CHANGELOG_FILE")"
  fi

  echo -n "$changelog_buf" > "$CHANGELOG_FILE"

  gh_set_env_var GHWF_CHANGELOG_BUF_KEY_SERIALIZED_ARR_STR ''
  tkl_declare_array GHWF_CHANGELOG_BUF_KEY_ARR

  gh_set_env_var GHWF_CHANGELOG_BUF_VALUE_SERIALIZED_ARR_STR ''
  tkl_declare_array GHWF_CHANGELOG_BUF_VALUE_ARR
}

tkl_register_call gh init_basic_workflow

tkl_set_return
