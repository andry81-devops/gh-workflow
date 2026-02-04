#!/usr/bin/env bash

function call()
{
  echo ">$*"
  "$@"
}

while IFS=$'\n\r' read -r path; do # IFS - with trim trailing line feeds
  if [[ -f "$path" ]]; then
    call chmod $1 "$path"
  fi
done <<< "`find "${@:2}"`"
