#!/bin/bash

function call()
{
  echo ">$*"
  "$@"
}

while IFS=$'\n\r' read -r path; do
  if [[ -f "$path" ]]; then
    call chmod $1 "$path"
  fi
done <<< "`find "${@:2}"`"
