> :information_source: this log lists user most visible changes

> :warning: to find all changes use [changelog.txt](https://github.com/andry81-devops/gh-workflow/tree/HEAD/changelog.txt) file in a directory

> :information_source: Legend: :shield: - security; :wrench: - fixed; :new: - new; :pencil: - changed; :twisted_rightwards_arrows: - refactor

## 2023.07.10:
* :wrench: fixed: bash/github/init-github-workflow.sh: `gh_eval_github_env_file` function rewrite to ignore value last line return

## 2023.07.09:
* :wrench: fixed: bash: `tkl_include*` correct nest level value
* :new: new: bash: Added usage of `tkl_register_call`/`tkl_execute_calls` and implemented postponed gh-workflow initialization, when the first `init_*` function calls only after the last `init-*.sh` script is included. This shall avoid recursed initialization execution in `init-*.sh` scripts, when one script is loaded, but another one is not yet.
* :pencil: changed: _externals/tacklelib/bash/tacklelib: merge with the latest changes

## 2023.07.06:
* :wrench: fixed: bash/github/init-basic-workflow.sh: completely removed `GITHUB_ENV` variables conditional load feature, because must always be loaded unconditionally, otherwise variables may be lost on the next shell line of the same GitHub Action step

## 2023.07.06:
* :new: new: bash/github/enable-print-buffering.sh: added script to explicitly enable print buffering

## 2023.07.06:
* :new: new: bash/github/utils.sh: `gh_unset_github_env_var`, `gh_push*_var_to_stack`, `gh_pop_var_from_stack` to be able to use variables stack between GitHub Action steps
* :pencil: changed: bash/github/utils.sh: `gh_set_env_var` now does export a variable instead of declare because `GITHUB_ENV` variables does export too
* :twisted_rightwards_arrows: refactor: bash/github/utils.sh: `gh_update_github_env_var` renamed to `gh_set_github_env_var`

## 2023.07.05:
* :wrench: fixed: bash/github/init-print-workflow.sh: annotations print duplication

## 2023.07.04:
* :wrench: fixed: bash: UTC timezone for URLs in `GHWF_REPO_STORE_COMMITS_URL`/`GHWF_REPO_STATS_COMMITS_URL` variables

## 2023.07.04:
* :wrench: fixed: bash/github/print-*.sh: unchanged or empty changelog file

## 2023.07.03:
* :wrench: fixed: bash/github/accum-rate-limits.sh: json format update

## 2023.07.02:
* :new: new: bash: use `ENABLE_REPO_STORE_COMMITS_URL_PRINT_TO_CHANGELOG`/`ENABLE_REPO_STATS_COMMITS_URL_PRINT_TO_CHANGELOG` and `GHWF_REPO_STORE_COMMITS_URL`/`GHWF_REPO_STATS_COMMITS_URL` variables to print `Content Store Repository`/`Statistic Output Repository` commit URL into being committed changelog file

## 2022.12.11:
* :wrench: fixed: bash/github/accum-stats.sh: avoid update if nothing changed including 14d `count` and `uniques` decrement by the last day

## 2022.12.09:
* :wrench: fixed: bash/github/accum-stats.sh: 14d `count` and `uniques` decrement by the last day

## 2022.10.12:
* :new: new: bash/github/is-flag-true-in-flags-expr-string.sh: added `gh_is_flag_true_in_flags_expr_string` function to evaluate flag expression strings

## 2022.10.12:
* :wrench: fixed: bash/github/print-*.sh: multiline annotations print
* :new: new: bash/_common: added `update-permissions.sh` script to update file permissions by `find` pattern all together (ex: `update-permissions.sh ug+x "$GH_WORKFLOW_ROOT" -iname '*.sh'`)
* :new: new: bash: print GitHub Actions workflow run number in case of print workflow run URL (`ENABLE_GITHUB_ACTIONS_RUN_URL_PRINT_TO_CHANGELOG=1`)
* :pencil: changed: bash/cache/accum-content.sh: export specific `GH_WORKFLOW_FLAGS` environment variable into nested bash contexts

## 2022.08.29:
* :new: new: bash/cache/accum-content.sh: added `entries[0]/init/shell` and `entries[0]/init/run` config content file fields to run entries initialization script
* :new: new: bash/github/init-xq-workflow.sh: added `XQ_CMDLINE_READ` and `XMLSTARLET_CMDLINE_SEL` variable to be able to use different xml query implementations

## 2022.08.28:
* :new: new: bash/cache/accum-content.sh: added `download-validate/shell` and `download-validate/run` config content file fields to run a file download validation script
* :new: new: bash/github: added `init-xq-workflow.sh` script to intialize workflow for the `xq` utility

## 2022.08.26:
* :new: new: bash: use `ENABLE_GITHUB_ACTIONS_RUN_URL_PRINT_TO_CHANGELOG` and `GHWF_GITHUB_ACTIONS_RUN_URL` variables to print GitHub Actions run URL into the changelog file

## 2022.08.26:
* :new: new: bash/github: added `eval-from-args.sh` with `--eval_github_env` flag to evaluate set of commands and additionally does evaluate `GITHUB_ENV` file before the execution

## 2022.08.22:
* :new: new: bash/cache/accum-content.sh: added `NO_DOWNLOAD_ENTRIES` and `NO_DOWNLOAD_ENTRIES_AND_CREATE_EMPTY_INSTEAD` variables to be able to debug locally without download
* :pencil: changed: bash: board/accum-stats.sh, cache/accum-content.sh, inpage/accum-downloads.sh: print-*.sh: always print stderr unconditionally to a return code
* :pencil: changed: bash/github/print-*.sh: `GHWF_PRINT_ERROR_BUF_STR` variable assign by `gh_set_env_var` to be able to debug using `GITHUB_ENV` file locally

## 2022.08.21:
* :new: new: bash/cache/accum-content.sh: added prev/next file size print
* :new: new: bash/cache: init-print-workflow.sh, accum-content.sh: enabled changed file notice messages groupping into a single annotation to fit the GitHub Actions summary maximum limit as 10 annotations (restored, because the message truncation actually was a message shrink into a single line, after expand it does restore back into multiline string)

## 2022.08.14:
* :wrench: fixed: bash/github: utils.sh, set-env-from-args.sh: missed to ignore `GITHUB_*` builtin variables, execution fixup
* :new: new: bash/github: init-basic-workflow.sh, enable-github-env-autoeval.sh: Ability to apply GitHub Actions job environment variables by the `GITHUB_ENV` file path automatically on each GitHub Actions job step line instead of on the next step only. A workflow does require to enable this explicitly using the `enable-github-env-autoeval.sh` script run.
* :pencil: changed: bash/github: utils.sh, set-env-from-args.sh: added global bash variables assign additionally to `GITHUB_ENV` file update to apply variables assign immediately for the same GitHub Actions job step line
* :twisted_rightwards_arrows: refactor: bash/github: `GH_*` global environment variables renamed into `GHWF_*`, added prefix to the rest

## 2022.08.13:
* :wrench: fixed: bash/github/print-*.sh: execution fixup
* :new: new: bash/github: init-print-workflow.sh, print-*.sh, *-print-annotation-group.sh: ability to group sequence of prints with the same annotation type into single annotation to prevent too many annotations because of the limit in the GitHub Actions job summary (currently is 10)
* :new: new: bash/github/accum-rate-limits.sh: added usage of a print annotation group

## 2022.08.12:
* :wrench: fixed: bash/github/print-*.sh: execution fixup
* :new: new: bash/github: init-print-workflow.sh, print-*.sh, flush-print-annotation.shs: print annotations buffering support
* :new: new: bash/github: init-basic-workflow.sh, print-*.sh: `CHANGELOG_BUF_STR` update between GitHub pipeline steps

## 2022.08.10:
* :wrench: fixed: bash/github/print-*.sh: notices, warnings, errors functions fixup
* :wrench: fixed: bash/github/accum-rate-limits.sh: json format change fixup
* :pencil: changed: bash/github/accum-rate-limits.sh: changed rate limits json format change message from an error to a warning

## 2022.08.09:
* :new: new: bash/github/init-yq-workflow.sh: added `ENABLE_YAML_DIFF_PRINT_BEFORE_PATCH`, `ENABLE_YAML_PRINT_AFTER_PATCH` variables to print diff/yaml file before patch instead of after edit (has priority over `ENABLE_YAML_DIFF_PRINT_AFTER_EDIT`, `ENABLE_YAML_PRINT_AFTER_EDIT` variables)

## 2022.08.08:
* :wrench: fixed: bash/github/init-yq-workflow.sh: `yq_restore_edited_uniform_diff` inaccurate blank lines position

## 2022.08.07:
* :new: new: bash/github: added `init-diff-workflow.sh` to support `diff` command workflow
* :new: new: bash/github/init-yq-workflow.sh: `yq_restore_edited_uniform_diff` function to restore yaml comments and blank lines
* :pencil: changed: bash/cache/accum-content.sh: use `yq_restore_edited_uniform_diff` function by default

## 2022.05.31:
* :new: new: bash/github/accum-stats.sh: added `STATS_REMOVED_DATES` return variable, print last removed dates additionally to the last changed dates
* :new: new: bash/github/accum-stats.sh: `ENABLE_COMMIT_MESSAGE_DATE_TIME_WITH_LAST_CHANGED_DATE_OFFSET` environment variable to insert datetime suffix as offset to the last changed date in format `-DDT` to note the closest changed date

## 2022.05.21:
* :wrench: fixed: bash: inpage/accum-downloads.sh, boards/accum-stats.sh: accidental exit with 0 on curl error

## 2022.05.19:
* :wrench: fixed: bash: inpage/accum-downloads.sh, boards/accum-stats.sh: incorrect save into `by_year` json file relative `downloads` counter
* :pencil: changed: bash: inpage/accum-downloads.sh, boards/accum-stats.sh: removed previous days increment/decrement counters, removed `STATS_PREV_DAY_*` return variables

## 2022.05.18:
* :wrench: fixed: bash/github/accum-stats.sh: `by_year` file rewrite on empty changes
* :pencil: changed: bash/github/accum-stats.sh: made `uniques` counter goes first in all messages

## 2022.05.17:
* :wrench: fixed: bash/github/accum-stats.sh: count/uniques minimum update fix
* :new: new: bash/github/accum-stats.sh: added `STATS_CHANGED_DATES` return variable to indicate the list of changed dates at the current date
* :pencil: changed: bash/github/accum-stats.sh: `STATS_CURRENT_DATE_*` return variables replaced by `STATS_LAST_CHANGED_DATE_*` return variable because last changed date and current date are different dates and the last changed date taken into account at the current date
* :pencil: changed: bash/github/accum-stats.sh: commit message is changed to indicate accumulation for the last changed date only instead of accumulation for all changed dates because the commit message will be placed for all files including `by_year/YYYY/YYYY-MM-DD.json` files

## 2022.05.17:
* :new: new: bash/github/accum-stats.sh: added `STATS_CURRENT_DATE_*_INC` and `STATS_CURRENT_DATE_*_DEC` return variables
* :pencil: changed: bash/github/accum-stats.sh: removed previous days increment/decrement counters and replaced by increment/decrement counters in a last date, removed `STATS_PREV_DAY_*` return variables

## 2022.05.16:
* :wrench: fixed: bash/github/accum-stats.sh: minor changelog output fix

## 2022.05.13:
* :wrench: fixed: bash/github/accum-stats.sh: current date count/uniques print into changelog file
* :new: new: bash/github/accum-stats.sh: save changed dates list into changelog file

## 2022.05.12:
* :new: new: bash/cache/accum-content.sh: added check of `NO_SKIP_UNEXPIRED_ENTRIES` to avoid skip of not yet expired files and force to download them

## 2022.05.11:
* :wrench: fixed: bash/inpage/accum-downloads.sh: save into `by_year` json file relative `downloads` counter instead of absolute
* :wrench: fixed: bash/boards/accum-stats.sh: save into `by_year` json file relative `downloads` counter instead of absolute
* :new: new: bash: added `commit_msg_entity` optional input parameter as replacement of `stat_entity` in the commit message
* :new: new: bash/github/accum-rate-limits.sh: added `stat_entity` required input parameter to select implementation
* :new: new: bash/github/accum-stats.sh: added `STATS_CURRENT_DATE_COUNT`, `STATS_CURRENT_DATE_UNIQUES`, `STATS_DATED_COUNT`, `STATS_DATED_UNIQUES`, `STATS_OUTDATED_COUNT`, `STATS_OUTDATED_UNIQUES` return variables
* :pencil: changed: bash/github/accum-stats.sh: removed `stats_list_key` input parameter, use `stat_entity` to select the implementation
* :pencil: changed: bash/board/accum-stats.sh: removed `board_name` input parameter
* :pencil: changed: bash/board/accum-stats.sh: changed the commit message, replaced previous day increment group by current date accumulated value
* :pencil: changed: bash/cache/accum-content.sh: removed `store_entity_path` input parameter
* :pencil: changed: bash/cache/accum-content.sh: changed the commit message, replaced previous day increment/decrement group by current date accumulated value
* :pencil: changed: bash/inpage/accum-downloads.sh: removed `stat_entity_path` input parameter
* :pencil: changed: bash/inpage/accum-downloads.sh: changed the commit message, replaced previous day increment group by current date accumulated value
* :pencil: changed: bash: swapped `COMMIT_MESSAGE_PREFIX` and `COMMIT_MESSAGE_SUFFIX` in all scripts to further improve readability in case of GitHub commit message truncation
* :pencil: changed: bash: added more accumulation details in the `COMMIT_MESSAGE_PREFIX` value
* :twisted_rightwards_arrows: refactor: bash: renamed `stat_entity_path` to `stat_entity` in the rest scripts

## 2022.05.08:
* :pencil: changed: bash/github/accum-content.sh: changed the commit message to improve readability in case of GitHub commit message truncation

## 2022.05.07:
* :wrench: fixed: bash: board/accum-stats.sh, cache/accum-content.sh, inpage/accum-downloads.sh: curl progress obscure by stderr is workarounded by grep it into stdout
* :new: new: bash/github/accum-content.sh: generate `content-index.yml` from `content-config.yml` if does not exist

## 2022.05.06:
* :wrench: fixed: bash/github/accum-content.sh: update downloaded file only if content is changed, increment skip counter if file hash is not changed (additionally to not yet expired files)
* :new: new: bash/github/accum-content.sh: `ERROR_ON_EMPTY_CHANGES_WITHOUT_ERRORS` environment variable to generate error on empty changes without errors to interrupt futher pipeline execution

## 2022.05.05:
* :wrench: fixed: bash/github/accum-content.sh: execution fix
* :wrench: fixed: bash/github/print-*.sh: accidental buffer unset in case of call twice to `gh_enable_print_*_buffering`
* :new: new: bash: curl stderr print on error

## 2022.05.04:
* :new: new: action.yml: added `COMMIT_MESSAGE_PREFIX` to split an automated user commit message into prefix and suffix parts
* :pencil: changed: bash/cache/accum-content.sh: treat empty downloaded files as invalid

## 2022.04.17:
* :pencil: changed: bash/github/accum-rate-limits.sh: replaced `core` statistic by `graphql` statistic because `rate` duplicates the `core` statistic, added `graphql` statistic difference

## 2022.03.30:
* :new: new: bash: accum-*.sh: added `ENABLE_COMMIT_MESSAGE_DATE_WITH_TIME` environment variable to add date with time to a generated commit message
* :pencil: changed: bash/github/accum-rate-limits.sh: removed `commit_message_insert_time` as a script parameter
* :pencil: changed: bash/github/print-*.sh: use script call as call to the `gh_print_*s` function instead of call to the `gh_print_*_ln` function to print each argument as a single line

## 2022.03.30:
* :new: new: bash/github: `init-curl-workflow.sh` initialization script
* :new: new: bash: print curl response on error support through `ENABLE_PRINT_CURL_RESPONSE_ON_ERROR` variable

## 2022.03.29:
* :pencil: changed: bash/github/print-*.sh: split `gh_print_*_ln` functions into `gh_print_*_ln` and `gh_print_*s` functions to print either all as a single line or all as multi line

## 2022.03.28:
* :wrench: fixed: bash/github/init-basic-workflow.sh: split a print buffer by line returns to print

## 2022.03.27:
* :wrench: fixed: bash: accum-*.sh: scripts execution

## 2022.03.25:
* :new: new: bash: accum-*.sh: enable warnings and errors print buffering on demand to resort warning prints after notices and error prints after warnings and notices
* :new: new: bash: accum-*.sh: added warnings and errors print lag

## 2022.03.25:
* :wrench: fixed: bash: accum-*.sh: missed to call `gh_prepend_changelog_file` on early exit

## 2022.03.24:
* :wrench: fixed: bash/github/init-basic-workflow.sh: avoid strings excessive expansion in `prepend_changelog_file` function
* :new: new: bash/github: `init-jq-workflow.sh` initialization script
* :new: new: _externals: partially added as an external copy of the tacklelib bash library
* :pencil: changed: bash: accum-*.sh: reduce text output size into the changelog file

## 2022.03.24:
* :wrench: fixed: bash: scripts execution
* :new: new: bash/github: `init-basic-workflow.sh`, `init-stats-workflow.sh` initialization scripts
* :new: new: bash/github: `set-env-from-args.sh` script to set environment variables from arguments
* :new: new: bash: changelog file support through `CONTINUE_ON_INVALID_INPUT`, `CONTINUE_ON_EMPTY_CHANGES`, `CONTINUE_ON_RESIDUAL_CHANGES`, `ENABLE_GENERATE_CHANGELOG_FILE`, `changelog_dir`, `changelog_txt` variables

## 2022.02.19:
* :new: new: bash/github/accum-rate-limit.sh: added `commit_message_insert_time` input parameter and `COMMIT_MESSAGE_DATE_TIME_PREFIX` output variable to use in a commit message

## 2022.02.17:
* :new: new: bash/github/accum-rate-limit.sh: accumulate rate limits bash script

## 2022.02.09:
* :wrench: fixed: bash/github/accum-stats.sh: missed to save by_year json using the current timestamp instead of github json timestamp

## 2022.02.07:
* :wrench: fixed: bash/*/accum-*.sh: basic protection from invalid values spread after read an invalid json file
* :wrench: fixed: bash/github/accum-stats.sh: code cleanup

## 2022.02.06:
* :wrench: fixed: bash: board/accum-stats.sh, inpage/accum-downloads.sh: exit with error if nothing is changed
* :wrench: fixed: bash/github/accum-stats.sh: missed to check by_year json changes and if changed then change the timestamp

## 2022.01.16:
* :new: new: bash: board/accum-stats.sh, inpage/accum-downloads.sh: `STATS_PREV_EXEC_*` and `STATS_PREV_DAY_*` variables to represent the script previous execution/day difference
* :pencil: changed: bash: board/accum-stats.sh, inpage/accum-downloads.sh: calculate difference in the `COMMIT_MESSAGE_SUFFIX` variable between current json file and the last change from the previous day instead of from the previous json file (independently to the pipeline scheduler times)

## 2022.01.14:
* :new: new: bash/*/accum-*.sh: `STATS_DATE_UTC` and `STATS_DATE_TIME_UTC` variables to represent the script execution times
* :new: new: bash/github/accum-stats.sh: `STATS_PREV_EXEC_*` and `STATS_PREV_DAY_*` variables to represent the script previous execution/day difference
* :pencil: changed: bash/github/accum-stats.sh: calculate difference in the `COMMIT_MESSAGE_SUFFIX` variable between current json file and the last change from the previous day instead of from the previous json file (independently to the pipeline scheduler times)

## 2022.01.01:
* :wrench: fixed: bash: missed `stats_dir` and `stats_json` variables check in respective scripts

## 2022.01.01:
* :new: new: bash: use `GH_WORKFLOW_ROOT` variable to include `gh-workflow` shell scripts as dependencies

## 2022.01.01:
* :pencil: changed: bash/github/print-*.sh: avoid output duplication, always print warnings/errors into stderr including GitHub pipeline

## 2021.12.31:
* :new: new: bash/github: `print-*.sh` scripts to directly call from GitHub pipeline for multiline messages (line per annotation)

## 2021.12.30:
* :new: new: accum-stats.sh, accum-downloads.sh: create `COMMIT_MESSAGE_SUFFIX` variable and print statistics change into GitHub pipeline

## 2021.12.30:
* :pencil: changed: accum-stats.sh, accum-downloads.sh: always print script main execution parameters, even if has no error or warning
