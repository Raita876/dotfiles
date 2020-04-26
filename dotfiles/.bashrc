#!/bin/bash

##############################################
# alias
##############################################
alias mv='mv -i'
alias rm='rm -i'

if type exa &> /dev/null; then
    alias ls='exa'
    alias ll='exa -lhF --time-style=long-iso'
else
    alias ll='ls -lhF'
fi


##############################################
# source .bash
##############################################
for rc in $(find "${HOME}/.bash/" -type f); do
    source "${rc}"
done
