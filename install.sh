#!/bin/bash
set -eu

readonly THIS_SCRIPT_DIR=$(cd "$(dirname $0)"; pwd)
readonly DOTFILES_AT_THIS_SCRIPT_DIR="${THIS_SCRIPT_DIR}/dotfiles"
readonly DOTFILES_AT_HOME_DIR="${HOME}/.dotfiles"
readonly DOTFILES_BK_AT_HOME_DIR="${HOME}/.dotfiles_bk"
readonly BASHRC="${HOME}/.bashrc"


function backup() {
    local target="$1"

    mkdir -p "${DOTFILES_BK_AT_HOME_DIR}"

    local bk
    bk="${DOTFILES_BK_AT_HOME_DIR}/$(basename "${target}").bk.$(date +%Y%m%d%H%M%S)"

    if [ -e "${target}" ]; then
        cp -r "${target}" "${bk}"
    fi
}

function install() {
    mkdir -p "${DOTFILES_AT_HOME_DIR}"
    rsync -ahv "${DOTFILES_AT_THIS_SCRIPT_DIR}/" "${DOTFILES_AT_HOME_DIR}/"

    for dot_file in $(find "${DOTFILES_AT_HOME_DIR}" -maxdepth 1); do
        if [ "${dot_file}" = "${DOTFILES_AT_HOME_DIR}" ]; then
            continue
        fi
        backup "${dot_file}"

        symlink="${HOME}/$(basename ${dot_file})"
        ln -sfvn "${dot_file}" "${symlink}"
    done

}

function main() {
    install
}

main "$@"
