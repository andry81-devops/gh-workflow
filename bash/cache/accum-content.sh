#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

# NOTE:
#
#   Script specific system variables (to set):
#
#     * NO_SKIP_UNEXPIRED_ENTRIES
#     * NO_DOWNLOAD_ENTRIES
#     * NO_DOWNLOAD_ENTRIES_AND_CREATE_EMPTY_INSTEAD
#
#   Yaml specific user variables (to set):
#
#     * DISABLE_YAML_EDIT_FORMAT_RESTORE_BY_DIFF_MERGE_WORKAROUND
#
#   The rest of variables is related to other scripts.
#

if [[ -z "$GH_WORKFLOW_ROOT" ]]; then
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
fi

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?

tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-basic-workflow.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-print-workflow.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-yq-workflow.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-curl-workflow.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-tacklelib-workflow.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/utils.sh"


# slashes fix
content_config_file="${content_config_file//\\//}"
content_index_file="${content_index_file//\\//}"

if [[ -z "$content_config_file" ]]; then
  gh_print_error_ln "$0: error: \`content_config_file\` variable must be defined."
  exit 255
fi

if [[ ! -f "$content_config_file" ]]; then
  gh_print_error_ln "$0: error: \`content_config_file\` file is not found: \`$content_config_file\`"
  exit 255
fi

if [[ -z "$content_index_file" ]]; then
  gh_print_error_ln "$0: error: \`content_index_file\` variable must be defined."
  exit 255
fi

content_index_dir="${content_index_dir%/}"

if [[ -z "$content_index_dir" ]]; then
  if [[ "${content_index_file////}" != "$content_index_file" ]]; then
    content_index_dir="${content_index_file%/*}"
  else
    content_index_dir=''
  fi
fi

current_date_time_utc="$(date --utc +%FT%TZ)"

current_date_utc="${current_date_time_utc/%T*}"

current_date_utc_sec="$(date --utc -d "${current_date_utc}Z" +%s)" # seconds from epoch to current date without time

current_date_time_utc_sec="$(date --utc -d "${current_date_time_utc}" +%s)" # seconds from epoch to current date with time

# on exit handler
tkl_push_trap 'gh_flush_print_buffers; gh_prepend_changelog_file' EXIT

gh_print_notice_and_write_to_changelog_text_ln "current date/time: $current_date_time_utc" "$current_date_time_utc:"

if (( ENABLE_GITHUB_ACTIONS_RUN_URL_PRINT_TO_CHANGELOG )) && [[ -n "$GHWF_GITHUB_ACTIONS_RUN_URL" ]]; then
  gh_write_notice_to_changelog_text_bullet_ln \
    "GitHub Actions Run: $GHWF_GITHUB_ACTIONS_RUN_URL # $GITHUB_RUN_NUMBER"
fi

if (( ENABLE_REPO_STORE_COMMITS_URL_PRINT_TO_CHANGELOG )) && [[ -n "$GHWF_REPO_STORE_COMMITS_URL" ]]; then
  (( repo_store_commits_url_until_date_time_utc_sec = current_date_time_utc_sec + 60 * 5 )) # +5min approximation and truncation to days

  repo_store_commits_url_until_date_time_utc="$(date --utc -d "@$repo_store_commits_url_until_date_time_utc_sec" +%FT%TZ)"

  repo_store_commits_url_until_date_utc_day="${repo_store_commits_url_until_date_time_utc/%T*}"

  gh_write_notice_to_changelog_text_bullet_ln \
    "Content Store Repository: $GHWF_REPO_STORE_COMMITS_URL&until=$repo_store_commits_url_until_date_utc_day"
fi

IFS=$'\n' read -r -d '' config_dirs_num config_entries_init_shell config_entries_init_run <<< \
  $("${YQ_CMDLINE_READ[@]}" \
    '(."content-config".entries[0].dirs|length),."content-config".entries[0].init.shell,."content-config".entries[0].init.run' \
    "$content_config_file")

# CAUTION:
#   Prevent of invalid values spread if upstream user didn't properly commit completely correct yaml file or didn't commit at all.
#
yq_fix_null \
  config_dirs_num:0 \
  config_entries_init_shell \
  config_entries_init_run

(( ! config_dirs_num )) && {
  gh_enable_print_buffering

  gh_print_error_and_write_to_changelog_text_bullet_ln "$0: error: content config is invalid or empty." "content config is invalid or empty"

  (( ! CONTINUE_ON_INVALID_INPUT )) && exit 255
}

# CAUTION:
#   We must use the exact shell file, otherwise the error: `sh: 1: Syntax error: redirection unexpected`
#

if [[ -z "$config_entries_init_shell" ]]; then
  config_entries_init_shell='bash'
fi

if [[ -n "$config_entries_init_run" ]]; then
  # execute in subprocess
  (
    # declare input variables
    tkl_export GH_WORKFLOW_ROOT     "$GH_WORKFLOW_ROOT"

    # export specific GitHub Actions workflow environment variables
    if [[ -n "${GH_WORKFLOW_FLAGS+x}" ]]; then
      tkl_export GH_WORKFLOW_FLAGS    "$GH_WORKFLOW_FLAGS"
    fi

    # execute
    "$config_entries_init_shell" -c "$config_entries_init_run"
  )

  if (( $? )); then
    gh_print_error_ln "$0: error: config entries init is failed: \`content-config/entries[0]/init\`"
    exit 255
  fi
fi

if [[ ! -f "$content_index_file" ]]; then
  # CAUTION:
  #   `content_index_dir` and `content_index_file_dir` is 2 different paths.
  #
  content_index_file_dir="${content_index_file%/*}"

  [[ -n "$content_index_file_dir" && ! -d "$content_index_file_dir" ]] && mkdir -p "$content_index_file_dir"

  {
    # CAUTION:
    #   We must use '' as an empty value placeholder to leave single quotes for it.
    #   If try to leave a value empty without quotes, then for a value with `:` character the `yq` parser will replace it with double-quotes or
    #   even change it, for example, in case of the UTC timestamp value.
    #
    echo \
"# This file is automatically updated by the GitHub action script: https://github.com/andry81-devops/gh-action--accum-content
#

content-index:

  timestamp: ''

  entries:

    - dirs:
"

    for i in $("${YQ_CMDLINE_READ[@]}" '."content-config".entries[0].dirs|keys|.[]' "$content_config_file"); do
      # CAUTION:
      #   Prevent of invalid values spread if upstream user didn't properly commit completely correct yaml file or didn't commit at all.
      #
      yq_is_null i && break

      IFS=$'\n' read -r -d '' config_dir <<< \
        $("${YQ_CMDLINE_READ[@]}" ".\"content-config\".entries[0].dirs[$i].dir" "$content_config_file") 2>/dev/null

      # CAUTION:
      #   Prevent of invalid values spread if upstream user didn't properly commit completely correct yaml file or didn't commit at all.
      #
      yq_fix_null \
        config_dir

      if [[ -n "$content_index_dir" ]]; then
        config_index_dir="${content_index_dir//\\//}${config_dir:+/}${config_dir//\\//}"
      else
        config_index_dir="${config_dir//\\//}"
      fi

      echo \
"        - dir: $config_index_dir
"

      for j in $("${YQ_CMDLINE_READ[@]}" ".\"content-config\".entries[0].dirs[$i].files|keys|.[]" "$content_config_file"); do
        # CAUTION:
        #   Prevent of invalid values spread if upstream user didn't properly commit completely correct yaml file or didn't commit at all.
        #
        yq_is_null j && break

        IFS=$'\n' read -r -d '' config_file <<< \
          $("${YQ_CMDLINE_READ[@]}" ".\"content-config\".entries[0].dirs[$i].files[$j].file" "$content_config_file") 2>/dev/null

        # CAUTION:
        #   Prevent of invalid values spread if upstream user didn't properly commit completely correct yaml file or didn't commit at all.
        #
        yq_fix_null \
          config_file

        if (( ! j )); then
          echo \
'          files:
'
        fi

        echo \
"            - file: $config_file
              queried-url:
              md5-hash:
              timestamp: ''
"
      done
    done
  } > "$content_index_file"
fi

#echo $'---\n'"$(<"$content_index_file")"$'\n---'

content_index_file_prev_md5_hash=( $(md5sum -b "$content_index_file") )

# drop forwarding backslash: https://unix.stackexchange.com/questions/424628/md5sum-prepends-to-the-checksum
#
content_index_file_prev_md5_hash="${content_index_file_prev_md5_hash#\\}"

if [[ -z "$TEMP_DIR" ]]; then # otherwise use exterenal TEMP_DIR
  TEMP_DIR="$(mktemp -d)"

  tkl_push_trap 'rm -rf "$TEMP_DIR"' EXIT
fi

gh_begin_print_annotation_group notice

function end_print_annotation_group_handler()
{
  gh_end_print_annotation_group

  # self update
  function end_print_annotation_group_handler() { :; }
}

tkl_push_trap 'end_print_annotation_group_handler' EXIT

stats_failed_inc=0
stats_skipped_inc=0
stats_expired_inc=0
stats_downloaded_inc=0
stats_changed_inc=0

no_download_entries=0

(( NO_DOWNLOAD_ENTRIES || NO_DOWNLOAD_ENTRIES_AND_CREATE_EMPTY_INSTEAD )) && no_download_entries=1

for i in $("${YQ_CMDLINE_READ[@]}" '."content-config".entries[0].dirs|keys|.[]' "$content_config_file"); do
  # CAUTION:
  #   Prevent of invalid values spread if upstream user didn't properly commit completely correct yaml file or didn't commit at all.
  #
  yq_is_null i && break

  IFS=$'\n' read -r -d '' config_dir config_sched_next_update_timestamp_delta <<< \
    $("${YQ_CMDLINE_READ[@]}" ".\"content-config\".entries[0].dirs[$i].dir,.\"content-config\".entries[0].dirs[$i].schedule.\"next-update\".timestamp" "$content_config_file") 2>/dev/null

  IFS=$'\n' read -r -d '' index_dir <<< \
    $("${YQ_CMDLINE_READ[@]}" ".\"content-index\".entries[0].dirs[$i].dir" "$content_index_file") 2>/dev/null

  # CAUTION:
  #   Prevent of invalid values spread if upstream user didn't properly commit completely correct yaml file or didn't commit at all.
  #
  yq_fix_null \
    config_dir \
    config_sched_next_update_timestamp_delta \
    index_dir

  if [[ -n "$content_index_dir" ]]; then
    config_index_dir="${content_index_dir//\\//}${config_dir:+/}${config_dir//\\//}"
  else
    config_index_dir="${config_dir//\\//}"
  fi

  if [[ "$config_index_dir" != "$index_dir" ]]; then
    gh_print_warning_ln "$0: warning: invalid index file directory entry: dirs[$i]:"$'\n'\
"  config_dir=\`$config_dir\`"$'\n'\
"  index_dir=\`$index_dir\`"$'\n'\
"  content_index_dir=\`$content_index_dir\`"$'\n'\
"  config_index_dir=\`$config_index_dir\`"

    (( stats_failed_inc++ ))

    continue
  fi

  for j in $("${YQ_CMDLINE_READ[@]}" ".\"content-config\".entries[0].dirs[$i].files|keys|.[]" "$content_config_file"); do
    # CAUTION:
    #   Prevent of invalid values spread if upstream user didn't properly commit completely correct yaml file or didn't commit at all.
    #
    yq_is_null j && break

    IFS=$'\n' read -r -d '' config_file config_query_url config_download_validate_shell config_download_validate_run <<< \
      $("${YQ_CMDLINE_READ[@]}" "\
.\"content-config\".entries[0].dirs[$i].files[$j].file,\
.\"content-config\".entries[0].dirs[$i].files[$j].\"query-url\",\
.\"content-config\".entries[0].dirs[$i].files[$j].\"download-validate\".\"shell\",\
.\"content-config\".entries[0].dirs[$i].files[$j].\"download-validate\".\"run\"" \
        "$content_config_file") 2>/dev/null

    IFS=$'\n' read -r -d '' index_file index_queried_url index_file_prev_size index_file_prev_md5_hash index_file_prev_timestamp <<< \
      $("${YQ_CMDLINE_READ[@]}" "\
.\"content-index\".entries[0].dirs[$i].files[$j].file,\
.\"content-index\".entries[0].dirs[$i].files[$j].\"queried-url\",\
.\"content-index\".entries[0].dirs[$i].files[$j].size,\
.\"content-index\".entries[0].dirs[$i].files[$j].\"md5-hash\",\
.\"content-index\".entries[0].dirs[$i].files[$j].timestamp" \
        "$content_index_file") 2>/dev/null

    # CAUTION:
    #   Prevent of invalid values spread if upstream user didn't properly commit completely correct yaml file or didn't commit at all.
    #
    yq_fix_null \
      config_file \
      config_query_url \
      config_download_validate_shell \
      config_download_validate_run \
      index_file \
      index_queried_url \
      index_file_prev_size \
      index_file_prev_md5_hash \
      index_file_prev_timestamp

    if [[ "$config_file" != "$index_file" ]]; then
      gh_print_warning_ln "$0: warning: invalid index file entry: dirs[$i].files[$j]:"$'\n'"  config_file=\`$config_file\`"$'\n'"  index_file=\`$index_file\`"

      (( stats_failed_inc++ ))
      (( stats_skipped_inc++ ))

      continue
    fi

    if [[ -z "$config_sched_next_update_timestamp_delta" ]]; then
      gh_print_warning_ln "$0: warning: invalid index file entry: dirs[$i].files[$j]:"$'\n'"  config_sched_next_update_timestamp_delta=\`$config_sched_next_update_timestamp_delta\`"

      (( stats_failed_inc++ ))
      (( stats_skipped_inc++ ))

      continue
    fi

    if [[ -f "$index_dir/$index_file" ]]; then
      is_index_file_prev_exist=1
    else
      is_index_file_prev_exist=0
    fi

    is_file_expired=0

    config_sched_next_update_timestamp_utc="$current_date_time_utc"
    index_file_expired_timestamp_delta=0

    if [[ -n "$index_file_prev_timestamp" ]]; then
      current_date_time_utc_sec="$(date --utc -d "$current_date_time_utc" +%s)"

      index_file_prev_timestamp_utc_sec="$(date --utc -d "$index_file_prev_timestamp" +%s)"

      (( config_sched_next_update_timestamp_delta_sec = $(date --utc -d "$config_sched_next_update_timestamp_delta" +%s) - current_date_utc_sec ))

      (( index_file_next_update_timestamp_utc_sec = index_file_prev_timestamp_utc_sec + config_sched_next_update_timestamp_delta_sec ))

      config_sched_next_update_timestamp_utc="$(date --utc -d "@$index_file_next_update_timestamp_utc_sec" +%FT%TZ)"

      (( index_file_expired_sec = current_date_time_utc_sec - index_file_next_update_timestamp_utc_sec ))

      index_file_expired_years=''
      index_file_expired_days=''
      index_file_expired_positive=1 # including zero

      if (( index_file_expired_sec < 0 )); then
        index_file_expired_positive=0
        (( index_file_expired_sec = -index_file_expired_sec ))
      fi

      if (( index_file_expired_sec >= 60 * 60 * 24 )); then
        (( index_file_expired_days = index_file_expired_sec / (60 * 60 * 24) ))
        (( index_file_expired_sec %= 60 * 60 * 24 ))
      fi

      if (( index_file_expired_days >= 365 )); then
        (( index_file_expired_years = index_file_expired_days / 365 ))
        (( index_file_expired_days %= 365 ))
      fi

      index_file_expired_timestamp_delta="$index_file_expired_years${index_file_expired_years:+"y "}$index_file_expired_days${index_file_expired_days:+"d "}$(date --utc -d "@$index_file_expired_sec" +%T)"

      if (( index_file_expired_positive )); then
        index_file_expired_timestamp_delta="+$index_file_expired_timestamp_delta"
        is_file_expired=1
      else
        index_file_expired_timestamp_delta="-$index_file_expired_timestamp_delta"
      fi
    else
      is_file_expired=1
    fi

    index_file_prev_updated_size=-1     # negative is not exist
    index_file_prev_updated_md5_hash=''

    if (( is_index_file_prev_exist )); then
      # to update the file size in the index file
      index_file_prev_updated_size="$(stat -c%s "$index_dir/$index_file")"

      # to update the file hash in the index file
      index_file_prev_updated_md5_hash=( $(md5sum -b "$index_dir/$index_file") )

      # drop forwarding backslash: https://unix.stackexchange.com/questions/424628/md5sum-prepends-to-the-checksum
      #
      index_file_prev_updated_md5_hash="${index_file_prev_updated_md5_hash#\\}"
    fi

    if (( ! is_file_expired )); then
      if (( ! NO_SKIP_UNEXPIRED_ENTRIES )); then
        echo "File is skipped: \`$index_dir/$index_file\`:
  expired-delta=\`$index_file_expired_timestamp_delta\` scheduled-timestamp=\`$index_file_prev_timestamp -> $config_sched_next_update_timestamp_utc\`
  size=\`$index_file_prev_updated_size\`"

        # update existing file hash on skip
        if (( index_file_prev_updated_size != index_file_prev_size )) || \
           [[ -n "$index_file_prev_updated_md5_hash" && "$index_file_prev_updated_md5_hash" != "$index_file_prev_md5_hash" ]]; then
          {
            # update index file fields
            if (( DISABLE_YAML_EDIT_FORMAT_RESTORE_BY_DIFF_MERGE_WORKAROUND )); then
              yq_edit 'content-index' 'edit' "$content_index_file" "$TEMP_DIR/content-index-[$i][$j]-edited.yml" \
                ".\"content-index\".entries[0].dirs[$i].files[$j].size=$index_file_prev_updated_size" \
                ".\"content-index\".entries[0].dirs[$i].files[$j].\"md5-hash\"=\"$index_file_prev_updated_md5_hash\"" && \
                mv -Tf "$TEMP_DIR/content-index-[$i][$j]-edited.yml" "$content_index_file"
            else
              yq_edit 'content-index' 'edit' "$content_index_file" "$TEMP_DIR/content-index-[$i][$j]-edited.yml" \
                ".\"content-index\".entries[0].dirs[$i].files[$j].size=$index_file_prev_updated_size" \
                ".\"content-index\".entries[0].dirs[$i].files[$j].\"md5-hash\"=\"$index_file_prev_updated_md5_hash\"" && \
                yq_diff "$TEMP_DIR/content-index-[$i][$j]-edited.yml" "$content_index_file" "$TEMP_DIR/content-index-[$i][$j]-edited.diff" && \
                yq_restore_edited_uniform_diff "$TEMP_DIR/content-index-[$i][$j]-edited.diff" "$TEMP_DIR/content-index-[$i][$j]-edited-restored.diff" && \
                yq_patch "$TEMP_DIR/content-index-[$i][$j]-edited.yml" "$TEMP_DIR/content-index-[$i][$j]-edited-restored.diff" "$TEMP_DIR/content-index-[$i][$j].yml" "$content_index_file"
            fi
          } || {
            (( stats_failed_inc++ ))
          }

          echo '---'
        fi

        (( stats_skipped_inc++ ))

        continue
      else
        echo "File is forced to download: \`$index_dir/$index_file\`:
  expired-delta=\`$index_file_expired_timestamp_delta\` scheduled-timestamp=\`$index_file_prev_timestamp -> $config_sched_next_update_timestamp_utc\`
  size=\`$index_file_prev_updated_size\`"
      fi
    else
      (( stats_expired_inc++ ))

      echo "File is expired: \`$index_dir/$index_file\`:
  expired-delta=\`$index_file_expired_timestamp_delta\` scheduled-timestamp=\`$index_file_prev_timestamp -> $config_sched_next_update_timestamp_utc\`
  size=\`$index_file_prev_updated_size\`"
    fi

    if (( is_index_file_prev_exist )); then
      # always reread from existing file
      index_file_prev_size="$index_file_prev_updated_size"
      index_file_prev_md5_hash="$index_file_prev_updated_md5_hash"
    fi

    [[ ! -d "$TEMP_DIR/content/$index_dir" ]] &&      mkdir -p "$TEMP_DIR/content/$index_dir"
    [[ ! -d "$TEMP_DIR/curl_stderr/$index_dir" ]] &&  mkdir -p "$TEMP_DIR/curl_stderr/$index_dir"

    echo "Downloading:"
    echo "  File: \`$index_dir/$index_file\`"
    echo "  URL:  $config_query_url"

    if (( ! no_download_entries )); then
      # CAUTION:
      #   The `sed` has to be used to ignore blank lines by replacing `CR` by `LF`.
      #   This is required for uniform parse the curl output in both verbose or non verbose mode.
      #
      eval curl $curl_flags -o '"$TEMP_DIR/content/$index_dir/$index_file"' '"$config_query_url"' 2>&1 | \
        tee "$TEMP_DIR/curl_stderr/$index_dir/$index_file" | \
        sed -E 's/\r([^\n])/\n\1/g' | \
        grep -P '^(?:  [% ] |(?:  |  \d|\d\d)\d |[<>] )'
      last_error=$?

      echo '---'

      # always print stderr unconditionally to a return code
      if [[ -s "$TEMP_DIR/curl_stderr/$index_dir/$index_file" ]]; then
        echo "$(<"$TEMP_DIR/curl_stderr/$index_dir/$index_file")"
        echo '---'
      fi

      if (( ! last_error )); then
        (( stats_downloaded_inc++ ))
      else
        (( stats_failed_inc++ ))

        gh_enable_print_buffering

        gh_print_error_and_write_to_changelog_text_ln \
          "$0: error: failed to download: \`$index_dir/$index_file\`" \
          "* error: failed to download: \`$index_dir/$index_file\`"

        continue
      fi
    else
      # just copy from the cache if exist or create empty
      if (( ! NO_DOWNLOAD_ENTRIES_AND_CREATE_EMPTY_INSTEAD )) && [[ -f "$index_dir/$index_file" ]]; then
        cp -T "$index_dir/$index_file" "$TEMP_DIR/content/$index_dir/$index_file"
      else
        echo -n '' > "$TEMP_DIR/content/$index_dir/$index_file"
      fi
    fi

    index_file_next_size="$(stat -c%s "$TEMP_DIR/content/$index_dir/$index_file")"

    # check on empty
    if (( ! index_file_next_size )); then
      (( stats_failed_inc++ ))

      gh_enable_print_buffering

      gh_print_warning_and_write_to_changelog_text_ln \
        "$0: warning: downloaded file is empty: \`$index_dir/$index_file\`" \
        "* warning: downloaded file is empty: \`$index_dir/$index_file\`"

      continue
    fi

    index_file_next_timestamp="$(date --utc +%FT%TZ)"

    index_file_next_md5_hash=( $(md5sum -b "$TEMP_DIR/content/$index_dir/$index_file") )

    # drop forwarding backslash: https://unix.stackexchange.com/questions/424628/md5sum-prepends-to-the-checksum
    #
    index_file_next_md5_hash="${index_file_next_md5_hash#\\}"

    is_index_file_invalid=0
    is_index_file_changed=0

    # update file only if content is changed
    if (( no_download_entries || ! is_index_file_prev_exist )) || [[ "$index_file_next_md5_hash" != "$index_file_prev_md5_hash" ]]; then
      # validate downloaded file
      if [[ -n "$config_download_validate_run" ]]; then
        # CAUTION:
        #   We must use the exact shell file, otherwise the error: `sh: 1: Syntax error: redirection unexpected`
        #

        if [[ -z "$config_download_validate_shell" ]]; then
          config_download_validate_shell='bash'
        fi

        # execute in subprocess
        (
          # declare input variables
          tkl_export GH_WORKFLOW_ROOT     "$GH_WORKFLOW_ROOT"

          # export specific GitHub Actions workflow environment variables
          if [[ -n "${GH_WORKFLOW_FLAGS+x}" ]]; then
            tkl_export GH_WORKFLOW_FLAGS    "$GH_WORKFLOW_FLAGS"
          fi

          tkl_export IS_STORED_FILE_EXIST "$is_index_file_prev_exist"

          tkl_export STORED_FILE          "$index_dir/$index_file"
          tkl_export STORED_FILE_SIZE     "$index_file_prev_size"
          tkl_export STORED_FILE_HASH     "$index_file_prev_md5_hash"

          tkl_export DOWNLOADED_FILE      "$TEMP_DIR/content/$index_dir/$index_file"
          tkl_export DOWNLOADED_FILE_SIZE "$index_file_next_size"
          tkl_export DOWNLOADED_FILE_HASH "$index_file_next_md5_hash"
          
          # execute
          "$config_download_validate_shell" -c "$config_download_validate_run"
        )

        if (( ! $? )); then
          (( ! no_download_entries )) && is_index_file_changed=1
        else
          is_index_file_invalid=1

          (( stats_failed_inc++ ))
        fi
      else
        (( ! no_download_entries )) && is_index_file_changed=1
      fi

      if (( is_index_file_changed )); then
        (( stats_changed_inc++ ))
      else
        (( stats_skipped_inc++ ))
      fi
    else
      (( stats_skipped_inc++ ))
    fi

    if (( is_index_file_changed )); then
      msg_prefix="File is changed"
    elif (( is_index_file_invalid )); then
      msg_prefix="File is not valid (skipped)"

      gh_write_to_changelog_text_ln \
        "* warning: downloaded file is not valid: \`$index_dir/$index_file\`:
  size=\`$index_file_prev_size -> $index_file_next_size\` md5-hash=\`$index_file_prev_md5_hash -> $index_file_next_md5_hash\`"

      # print the invalid file
      if (( 65536 >= index_file_next_size )); then
        echo $'---\n'"$(<"$TEMP_DIR/content/$index_dir/$index_file")"$'\n---'
      fi
    elif (( no_download_entries )); then
      msg_prefix="File is skipped (no download)"
    else
      msg_prefix="File is skipped"
    fi

    if (( is_index_file_changed )); then
      gh_print_notice_and_write_to_changelog_text_ln \
        "$msg_prefix: \`$index_dir/$index_file\`:
  size=\`$index_file_prev_size -> $index_file_next_size\` md5-hash=\`$index_file_prev_md5_hash -> $index_file_next_md5_hash\`
  expired-delta=\`$index_file_expired_timestamp_delta\` scheduled-timestamp=\`$index_file_prev_timestamp -> $config_sched_next_update_timestamp_utc\` update-timestamp=\`$index_file_next_timestamp\`" \
        "* changed: \`$index_dir/$index_file\`:
  size=\`$index_file_prev_size -> $index_file_next_size\` md5-hash=\`$index_file_prev_md5_hash -> $index_file_next_md5_hash\`
  expired-delta=\`$index_file_expired_timestamp_delta\` scheduled-timestamp=\`$index_file_prev_timestamp -> $config_sched_next_update_timestamp_utc\` update-timestamp=\`$index_file_next_timestamp\`"

      [[ ! -d "$index_dir" ]] && mkdir -p "$index_dir"

      mv -Tf "$TEMP_DIR/content/$index_dir/$index_file" "$index_dir/$index_file"
    else
      echo "$msg_prefix: \`$index_dir/$index_file\`:
  size=\`$index_file_prev_size -> $index_file_next_size\` md5-hash=\`$index_file_prev_md5_hash -> $index_file_next_md5_hash\`
  expired-delta=\`$index_file_expired_timestamp_delta\` scheduled-timestamp=\`$index_file_prev_timestamp -> $config_sched_next_update_timestamp_utc\` update-timestamp=\`$index_file_next_timestamp\`"
    fi

    {
      # update index file fields
      if (( is_index_file_changed )); then
        if (( DISABLE_YAML_EDIT_FORMAT_RESTORE_BY_DIFF_MERGE_WORKAROUND )); then
          yq_edit 'content-index' 'edit' "$content_index_file" "$TEMP_DIR/content-index-[$i][$j]-edited.yml" \
            ".\"content-index\".entries[0].dirs[$i].files[$j].\"queried-url\"=\"$config_query_url\"" \
            ".\"content-index\".entries[0].dirs[$i].files[$j].size=$index_file_next_size" \
            ".\"content-index\".entries[0].dirs[$i].files[$j].\"md5-hash\"=\"$index_file_next_md5_hash\"" \
            ".\"content-index\".entries[0].dirs[$i].files[$j].timestamp=\"$index_file_next_timestamp\"" && \
            mv -Tf "$TEMP_DIR/content-index-[$i][$j]-edited.yml" "$content_index_file"
        else
          yq_edit 'content-index' 'edit' "$content_index_file" "$TEMP_DIR/content-index-[$i][$j]-edited.yml" \
            ".\"content-index\".entries[0].dirs[$i].files[$j].\"queried-url\"=\"$config_query_url\"" \
            ".\"content-index\".entries[0].dirs[$i].files[$j].size=$index_file_next_size" \
            ".\"content-index\".entries[0].dirs[$i].files[$j].\"md5-hash\"=\"$index_file_next_md5_hash\"" \
            ".\"content-index\".entries[0].dirs[$i].files[$j].timestamp=\"$index_file_next_timestamp\"" && \
            yq_diff "$TEMP_DIR/content-index-[$i][$j]-edited.yml" "$content_index_file" "$TEMP_DIR/content-index-[$i][$j]-edited.diff" && \
            yq_restore_edited_uniform_diff "$TEMP_DIR/content-index-[$i][$j]-edited.diff" "$TEMP_DIR/content-index-[$i][$j]-edited-restored.diff" && \
            yq_patch "$TEMP_DIR/content-index-[$i][$j]-edited.yml" "$TEMP_DIR/content-index-[$i][$j]-edited-restored.diff" "$TEMP_DIR/content-index-[$i][$j].yml" "$content_index_file"
        fi
      else
        if (( DISABLE_YAML_EDIT_FORMAT_RESTORE_BY_DIFF_MERGE_WORKAROUND )); then
          yq_edit 'content-index' 'edit' "$content_index_file" "$TEMP_DIR/content-index-[$i][$j]-edited.yml" \
            ".\"content-index\".entries[0].dirs[$i].files[$j].timestamp=\"$index_file_next_timestamp\"" && \
            mv -Tf "$TEMP_DIR/content-index-[$i][$j]-edited.yml" "$content_index_file"
        else
          yq_edit 'content-index' 'edit' "$content_index_file" "$TEMP_DIR/content-index-[$i][$j]-edited.yml" \
            ".\"content-index\".entries[0].dirs[$i].files[$j].timestamp=\"$index_file_next_timestamp\"" && \
            yq_diff "$TEMP_DIR/content-index-[$i][$j]-edited.yml" "$content_index_file" "$TEMP_DIR/content-index-[$i][$j]-edited.diff" && \
            yq_restore_edited_uniform_diff "$TEMP_DIR/content-index-[$i][$j]-edited.diff" "$TEMP_DIR/content-index-[$i][$j]-edited-restored.diff" && \
            yq_patch "$TEMP_DIR/content-index-[$i][$j]-edited.yml" "$TEMP_DIR/content-index-[$i][$j]-edited-restored.diff" "$TEMP_DIR/content-index-[$i][$j].yml" "$content_index_file"
        fi
      fi
    } || {
      (( stats_failed_inc++ ))
    }

    echo '---'
  done
done

# remove grouping
end_print_annotation_group_handler

content_index_file_next_md5_hash=( $(md5sum -b "$content_index_file") )

# drop forwarding backslash: https://unix.stackexchange.com/questions/424628/md5sum-prepends-to-the-checksum
#
content_index_file_next_md5_hash="${content_index_file_next_md5_hash#\\}"

if (( stats_changed_inc )) || [[ "$content_index_file_next_md5_hash" != "$content_index_file_prev_md5_hash" ]]; then
  {
    # update index file change timestamp
    if (( DISABLE_YAML_EDIT_FORMAT_RESTORE_BY_DIFF_MERGE_WORKAROUND )); then
      yq_edit 'content-index' 'edit' "$content_index_file" "$TEMP_DIR/content-index-[timestamp]-edited.yml" \
        ".\"content-index\".timestamp=\"$index_file_next_timestamp\"" && \
        mv -Tf "$TEMP_DIR/content-index-[timestamp]-edited.yml" "$content_index_file"
    else
      yq_edit 'content-index' 'edit' "$content_index_file" "$TEMP_DIR/content-index-[timestamp]-edited.yml" \
        ".\"content-index\".timestamp=\"$index_file_next_timestamp\"" && \
        yq_diff "$TEMP_DIR/content-index-[timestamp]-edited.yml" "$content_index_file" "$TEMP_DIR/content-index-[timestamp]-edited.diff" && \
        yq_restore_edited_uniform_diff "$TEMP_DIR/content-index-[timestamp]-edited.diff" "$TEMP_DIR/content-index-[timestamp]-edited-restored.diff" && \
        yq_patch "$TEMP_DIR/content-index-[timestamp]-edited.yml" "$TEMP_DIR/content-index-[timestamp]-edited-restored.diff" "$TEMP_DIR/content-index-[timestamp].yml" "$content_index_file"
    fi
  } || {
    (( stats_failed_inc++ ))
  }

  echo '---'
fi

gh_print_notice_and_write_to_changelog_text_bullet_ln "failed / skipped expired / downloaded changed: $stats_failed_inc / $stats_skipped_inc $stats_expired_inc / $stats_downloaded_inc $stats_changed_inc"

if (( ! stats_changed_inc )); then
  gh_enable_print_buffering

  gh_print_warning_ln "$0: warning: nothing is changed, no new downloads."

  (( ! CONTINUE_ON_EMPTY_CHANGES )) && exit 255

  if (( ! stats_failed_inc )); then
    (( ERROR_ON_EMPTY_CHANGES_WITHOUT_ERRORS )) && exit 255
  fi
fi

commit_message_date_time_prefix="$current_date_utc"

if (( ENABLE_COMMIT_MESSAGE_DATE_WITH_TIME )); then
  commit_message_date_time_prefix="${current_date_time_utc%:*Z}Z"
fi

# return output variables

# CAUTION:
#   We must explicitly state the content accumulation time in the script, because
#   the time taken from the input and the time set to commit changes ARE DIFFERENT
#   and may be shifted to the next day.
#
gh_set_env_var STATS_DATE_UTC                     "$current_date_utc"
gh_set_env_var STATS_DATE_TIME_UTC                "$current_date_time_utc"

gh_set_env_var STATS_FAILED_INC                   "$stats_failed_inc"
gh_set_env_var STATS_SKIPPED_INC                  "$stats_skipped_inc"
gh_set_env_var STATS_EXPIRED_INC                  "$stats_expired_inc"
gh_set_env_var STATS_DOWNLOADED_INC               "$stats_downloaded_inc"
gh_set_env_var STATS_CHANGED_INC                  "$stats_changed_inc"

gh_set_env_var COMMIT_MESSAGE_DATE_TIME_PREFIX    "$commit_message_date_time_prefix"

gh_set_env_var COMMIT_MESSAGE_PREFIX              "$stats_failed_inc $stats_skipped_inc $stats_expired_inc $stats_downloaded_inc $stats_changed_inc < fl sk ex dl ch"
gh_set_env_var COMMIT_MESSAGE_SUFFIX              "$commit_msg_entity"

tkl_set_return
