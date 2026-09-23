#!/usr/bin/env bash

# Custom wrapper script to rename OpenCode header/greeting to WEBCODE
# usage: ./webcode.sh or copy to bin

export BXPLOIT_ROOT="$HOME/.bxploit"
export OPENCODE_AGENT="web"

opencode "$@"
