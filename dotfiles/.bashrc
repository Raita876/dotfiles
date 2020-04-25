#!/bin/bash
set -eu

# alias
alias ls='ls -FG'

for rc in $(find "${HOME}/.bash" -type f); do
    source "${rc}"
done
