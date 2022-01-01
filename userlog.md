> :information_source: this log lists user most visible changes

> :warning: to find all changes use [changelog.txt](https://github.com/andry81/gh-workflow/blob/master/changelog.txt) file in a directory

## 2022.01.01:
* new: bash: use `GH_WORKFLOW_ROOT` variable to include `gh-workflow` shell scripts as dependencies

## 2022.01.01:
* changed: bash/github/print-*.sh: avoid output duplication, always print warnings/errors into stderr including GitHub pipeline

## 2021.12.31:
* new: bash/github: `print-*.sh` scripts to directly call from GitHub pipeline for multiline messages (line per annotation)

## 2021.12.30:
* new: accum-stats.sh, accum-downloads.sh: create `COMMIT_MESSAGE_SUFFIX` variable and print statistics change into GitHub pipeline

## 2021.12.30:
* changed: accum-stats.sh, accum-downloads.sh: always print script main execution parameters, even if has no error or warning
