#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

get_properties_config_value() {
  local property="$1"
  local config_file="$2"
  grep "^${property}\s*=" "$config_file" |
    grep -v "^\s*#" |
    sed "s/^${property}\s*=\s*//;s/^[\"']\(.*\)[\"']$/\1/;s/\s*$//"
}
