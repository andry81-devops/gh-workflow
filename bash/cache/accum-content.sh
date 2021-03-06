#!/bin/bash

# NOTE:
#   This is a composite script to use from a composite GitHub action.
#

[[ -z "$GH_WORKFLOW_ROOT" ]] && {
  echo "$0: error: \`GH_WORKFLOW_ROOT\` variable must be defined." >&2
  exit 255
}

source "$GH_WORKFLOW_ROOT/_externals/tacklelib/bash/tacklelib/bash_tacklelib" || exit $?

tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-basic-workflow.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-yq-workflow.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-curl-workflow.sh"
tkl_include_or_abort "$GH_WORKFLOW_ROOT/bash/github/init-tacklelib-workflow.sh"


# slashes fix
content_config_file="${content_config_file//\\//}"
content_index_file="${content_index_file//\\//}"

[[ -z "$content_config_file" ]] && {
  gh_print_error_ln "$0: error: \`content_config_file\` variable must be defined."
  exit 255
}

[[ ! -f "$content_config_file" ]] && {
  gh_print_error_ln "$0: error: \`content_config_file\` file is not found: \`$content_config_file\`"
  exit 255
}

[[ -z "$content_index_file" ]] && {
  gh_print_error_ln "$0: error: \`content_index_file\` variable must be defined."
  exit 255
}

content_index_dir="${content_index_dir%/}"

if [[ -z "$content_index_dir" ]]; then
  if [[ "${content_index_file////}" != "$content_index_file" ]]; then
    content_index_dir="${content_index_file%/*}"
  else
    content_index_dir=''
  fi
fi

current_date_time_utc="$(date --utc +%FT%TZ)"

# on exit handler
tkl_push_trap 'gh_flush_print_buffers; gh_prepend_changelog_file' EXIT

gh_print_notice_and_write_to_changelog_text_ln "current date/time: $current_date_time_utc" "$current_date_time_utc:"

current_date_utc="${current_date_time_utc/%T*}"

current_date_utc_sec="$(date --utc -d "${current_date_utc}Z" +%s)" # seconds from epoch to current date

IFS=$'\n' read -r -d '' dirs_num <<< $("${YQ_CMDLINE_READ[@]}" '."content-config".entries[0].dirs|length' $content_config_file)

# CAUTION:
#   Prevent of invalid values spread if upstream user didn't properly commit completely correct yaml file or didn't commit at all.
#
yq_fix_null \
  dirs_num:0

(( ! dirs_num )) && {
  gh_enable_print_buffering

  gh_print_error_and_write_to_changelog_text_bullet_ln "$0: error: content config is invalid or empty." "content config is invalid or empty"

  (( ! CONTINUE_ON_INVALID_INPUT )) && exit 255
}

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
    #   even change it in case of the UTC timestamp value.
    #
    echo \
"# This file is automatically updated by the GitHub action script: https://github.com/andry81-devops/gh-action--accum-content
#

content-index:

  timestamp: ''

  entries:

    - dirs:
"

    for i in $("${YQ_CMDLINE_READ[@]}" '."content-config".entries[0].dirs|keys|.[]' $content_config_file); do
      # CAUTION:
      #   Prevent of invalid values spread if upstream user didn't properly commit completely correct yaml file or didn't commit at all.
      #
      yq_is_null i && break

      IFS=$'\n' read -r -d '' config_dir <<< \
        $("${YQ_CMDLINE_READ[@]}" ".\"content-config\".entries[0].dirs[$i].dir" $content_config_file) 2>/dev/null

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

      for j in $("${YQ_CMDLINE_READ[@]}" ".\"content-config\".entries[0].dirs[$i].files|keys|.[]" $content_config_file); do
        # CAUTION:
        #   Prevent of invalid values spread if upstream user didn't properly commit completely correct yaml file or didn't commit at all.
        #
        yq_is_null j && break

        IFS=$'\n' read -r -d '' config_file <<< \
          $("${YQ_CMDLINE_READ[@]}" ".\"content-config\".entries[0].dirs[$i].files[$j].file" $content_config_file) 2>/dev/null

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

TEMP_DIR="$(mktemp -d)"

tkl_push_trap 'rm -rf "$TEMP_DIR"' EXIT

stats_failed_inc=0
stats_skipped_inc=0
stats_expired_inc=0
stats_downloaded_inc=0
stats_changed_inc=0

for i in $("${YQ_CMDLINE_READ[@]}" '."content-config".entries[0].dirs|keys|.[]' $content_config_file); do
  # CAUTION:
  #   Prevent of invalid values spread if upstream user didn't properly commit completely correct yaml file or didn't commit at all.
  #
  yq_is_null i && break

  IFS=$'\n' read -r -d '' config_dir config_sched_next_update_timestamp_delta <<< \
    $("${YQ_CMDLINE_READ[@]}" ".\"content-config\".entries[0].dirs[$i].dir,.\"content-config\".entries[0].dirs[$i].schedule.\"next-update\".timestamp" $content_config_file) 2>/dev/null

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
    gh_print_warning_ln "$0: warning: invalid index file directory entry: dirs[$i]:"$'\n'"  config_index_dir=\`$config_index_dir\`"$'\n'"  index_dir=\`$index_dir\`"

    (( stats_failed_inc++ ))

    continue
  fi

  for j in $("${YQ_CMDLINE_READ[@]}" ".\"content-config\".entries[0].dirs[$i].files|keys|.[]" $content_config_file); do
    # CAUTION:
    #   Prevent of invalid values spread if upstream user didn't properly commit completely correct yaml file or didn't commit at all.
    #
    yq_is_null j && break

    IFS=$'\n' read -r -d '' config_file config_query_url <<< \
      $("${YQ_CMDLINE_READ[@]}" ".\"content-config\".entries[0].dirs[$i].files[$j].file,.\"content-config\".entries[0].dirs[$i].files[$j].\"query-url\"" $content_config_file) 2>/dev/null

    IFS=$'\n' read -r -d '' index_file index_queried_url index_file_prev_md5_hash index_file_prev_timestamp <<< \
      $("${YQ_CMDLINE_READ[@]}" ".\"content-index\".entries[0].dirs[$i].files[$j].file,.\"content-index\".entries[0].dirs[$i].files[$j].\"queried-url\",.\"content-index\".entries[0].dirs[$i].files[$j].\"md5-hash\",.\"content-index\".entries[0].dirs[$i].files[$j].timestamp" "$content_index_file") 2>/dev/null

    # CAUTION:
    #   Prevent of invalid values spread if upstream user didn't properly commit completely correct yaml file or didn't commit at all.
    #
    yq_fix_null \
      config_file \
      config_query_url \
      index_file \
      index_queried_url \
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

    config_sched_next_update_timestamp_utc=$current_date_time_utc
    index_file_expired_timestamp_delta=0

    if [[ -n "$index_file_prev_timestamp" ]]; then
      current_date_time_utc_sec="$(date --utc -d "$current_date_time_utc" +%s)"

      index_file_prev_timestamp_utc_sec="$(date --utc -d "$index_file_prev_timestamp" +%s)"

      (( config_sched_next_update_timestamp_delta_sec = $(date --utc -d "$config_sched_next_update_timestamp_delta" +%s) - current_date_utc_sec ))

      (( index_file_next_update_timestamp_utc_sec = index_file_prev_timestamp_utc_sec + config_sched_next_update_timestamp_delta_sec ))

      config_sched_next_update_timestamp_utc="$(date --utc -d "@$index_file_next_update_timestamp_utc_sec" +%FT%TZ)"

      (( index_file_expired_sec = current_date_time_utc_sec - index_file_next_update_timestamp_utc_sec ))

      if (( index_file_expired_sec > 0 )); then
        index_file_expired_timestamp_delta=+$(date --utc -d "@$index_file_expired_sec" +%T)
        is_file_expired=1
      else
        (( index_file_expired_sec = -index_file_expired_sec ))
        index_file_expired_timestamp_delta=-$(date --utc -d "@$index_file_expired_sec" +%T)
      fi
    else
      is_file_expired=1
    fi

    index_file_next_md5_hash=''
    if (( is_index_file_prev_exist )); then
      # to update the file hash in the index file
      index_file_next_md5_hash=( $(md5sum -b "$index_dir/$index_file") )
    fi

    if (( ! is_file_expired )); then
      if (( ! NO_SKIP_UNEXPIRED_ENTRIES )); then
        echo "File is skipped: prev-timestamp=\`$index_file_prev_timestamp\` sched-timestamp=\`$config_sched_next_update_timestamp_utc\` expired-delta=\`$index_file_expired_timestamp_delta\` existed=\`$is_index_file_prev_exist\` file=\`$index_dir/$index_file\`"

        # update existing file hash on skip
        if [[ -n "$index_file_next_md5_hash" && "$index_file_next_md5_hash" != "$index_file_prev_md5_hash" ]]; then
          index_file_next_timestamp="$(date --utc +%FT%TZ)"

          yq_edit 'content-index' "$content_index_file" "$TEMP_DIR/content-index-[$i][$j]-edited.yml" \
            ".\"content-index\".entries[0].dirs[$i].files[$j].\"md5-hash\"=\"$index_file_next_md5_hash\"" && \
            yq_diff "$content_index_file" "$TEMP_DIR/content-index-[$i][$j]-edited.yml" "$TEMP_DIR/content-index-[$i][$j]-edited.diff" && \
            yq_patch "$content_index_file" "$TEMP_DIR/content-index-[$i][$j]-edited.diff" "$TEMP_DIR/content-index-[$i][$j].yml" "$content_index_file"

          echo '---'
        fi

        (( stats_skipped_inc++ ))

        continue
      else
        echo "File is forced to download: prev-timestamp=\`$index_file_prev_timestamp\` sched-timestamp=\`$config_sched_next_update_timestamp_utc\` expired-delta=\`$index_file_expired_timestamp_delta\` existed=\`$is_index_file_prev_exist\` file=\`$index_dir/$index_file\`"
      fi
    else
      (( stats_expired_inc++ ))

      echo "File is expired: prev-timestamp=\`$index_file_prev_timestamp\` sched-timestamp=\`$config_sched_next_update_timestamp_utc\` expired-delta=\`$index_file_expired_timestamp_delta\` existed=\`$is_index_file_prev_exist\` file=\`$index_dir/$index_file\`"
    fi

    if (( is_index_file_prev_exist )); then
      # always reread from existing file
      index_file_prev_md5_hash=$index_file_next_md5_hash
    fi

    [[ ! -d "$TEMP_DIR/content/$index_dir" ]] &&      mkdir -p "$TEMP_DIR/content/$index_dir"
    [[ ! -d "$TEMP_DIR/curl_stderr/$index_dir" ]] &&  mkdir -p "$TEMP_DIR/curl_stderr/$index_dir"

    echo "Downloading:"
    echo "  file: \`$index_dir/$index_file\`"
    echo "  URL:  $config_query_url"

    # CAUTION:
    #   The `sed` has to be used to ignore blank lines by replacing `CR` by `LF`.
    #   This is required for uniform parse the curl output in both verbose or non verbose mode.
    #
    if eval curl $curl_flags -o "\$TEMP_DIR/content/\$index_dir/\$index_file" "\$config_query_url" 2>&1 | tee "$TEMP_DIR/curl_stderr/$index_dir/$index_file" | sed -E 's/\r([^\n])/\n\1/g' | grep -P '^(?:  [% ] |(?:  |  \d|\d\d)\d |[<>] )'; then
      (( stats_downloaded_inc++ ))

      echo '---'
    else
      echo '---'

      if [[ -s "$TEMP_DIR/curl_stderr/$index_dir/$index_file" ]]; then
        echo "$(<"$TEMP_DIR/curl_stderr/$index_dir/$index_file")"
        echo '---'
      fi

      (( stats_failed_inc++ ))

      gh_enable_print_buffering

      gh_print_error_and_write_to_changelog_text_ln \
        "$0: error: failed to download: \`$index_dir/$index_file\`" \
        "* error: $index_dir/$index_file: failed to download"
      continue
    fi

    # check on empty
    if [[ ! -s "$TEMP_DIR/content/$index_dir/$index_file" ]]; then
      if [[ -s "$TEMP_DIR/curl_stderr/$index_dir/$index_file" ]]; then
        echo "$(<"$TEMP_DIR/curl_stderr/$index_dir/$index_file")"
        echo '---'
      fi

      (( stats_failed_inc++ ))

      gh_enable_print_buffering

      gh_print_warning_and_write_to_changelog_text_ln \
        "$0: warning: downloaded file is empty: \`$index_dir/$index_file\`" \
        "* warning: $index_dir/$index_file: downloaded file is empty"
      continue
    fi

    index_file_next_timestamp="$(date --utc +%FT%TZ)"

    index_file_next_md5_hash=( $(md5sum -b "$TEMP_DIR/content/$index_dir/$index_file") )

    if [[ "$index_file_next_md5_hash" != "$index_file_prev_md5_hash" ]]; then
      echo "File MD5 hash is changed: new=\`$index_file_next_md5_hash\` prev=\`$index_file_prev_md5_hash\`"
    else
      echo "File MD5 hash is not changed: \`$index_file_next_md5_hash\`"
    fi

    # update file only if content is changed
    if (( ! is_index_file_prev_exist )) || [[ "$index_file_next_md5_hash" != "$index_file_prev_md5_hash" ]]; then
      (( stats_changed_inc++ ))

      gh_print_notice_and_write_to_changelog_text_ln \
        "changed: $index_dir/$index_file: md5-hash=\`$index_file_next_md5_hash\` existed=\`$is_index_file_prev_exist\` sched-timestamp=\`$config_sched_next_update_timestamp_utc\` prev-timestamp=\`$index_file_prev_timestamp\` expired-delta=\`$index_file_expired_timestamp_delta\` prev-md5-hash=\`$index_file_prev_md5_hash\`" \
        "* changed: $index_dir/$index_file: md5-hash=\`$index_file_next_md5_hash\` existed=\`$is_index_file_prev_exist\` sched-timestamp=\`$config_sched_next_update_timestamp_utc\` prev-timestamp=\`$index_file_prev_timestamp\` expired-delta=\`$index_file_expired_timestamp_delta\` prev-md5-hash=\`$index_file_prev_md5_hash\`"

      [[ ! -d "$index_dir" ]] && mkdir -p "$index_dir"

      mv -Tf "$TEMP_DIR/content/$index_dir/$index_file" "$index_dir/$index_file"
    else
      (( stats_skipped_inc++ ))
    fi

    # update index file fields
    yq_edit 'content-index' "$content_index_file" "$TEMP_DIR/content-index-[$i][$j]-edited.yml" \
      ".\"content-index\".entries[0].dirs[$i].files[$j].\"queried-url\"=\"$config_query_url\"" \
      ".\"content-index\".entries[0].dirs[$i].files[$j].\"md5-hash\"=\"$index_file_next_md5_hash\"" \
      ".\"content-index\".entries[0].dirs[$i].files[$j].timestamp=\"$index_file_next_timestamp\"" && \
      yq_diff "$content_index_file" "$TEMP_DIR/content-index-[$i][$j]-edited.yml" "$TEMP_DIR/content-index-[$i][$j]-edited.diff" && \
      yq_patch "$content_index_file" "$TEMP_DIR/content-index-[$i][$j]-edited.diff" "$TEMP_DIR/content-index-[$i][$j].yml" "$content_index_file"

    echo '---'
  done
done

content_index_file_next_md5_hash=( $(md5sum -b "$content_index_file") )

if (( stats_changed_inc )) || [[ "$content_index_file_next_md5_hash" != "$content_index_file_prev_md5_hash" ]]; then
  # update index file change timestamp
  yq_edit 'content-index' "$content_index_file" "$TEMP_DIR/content-index-[timestamp].yml" \
    ".\"content-index\".timestamp=\"$index_file_next_timestamp\"" && \
    yq_diff "$content_index_file" "$TEMP_DIR/content-index-[timestamp].yml" "$TEMP_DIR/content-index-[timestamp].diff" && \
    yq_patch "$content_index_file" "$TEMP_DIR/content-index-[timestamp].diff" "$TEMP_DIR/content-index-[timestamp].yml" "$content_index_file"

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
