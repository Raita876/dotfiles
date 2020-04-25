#!/bin/bash
set -eu

readonly THIS_SCRIPT_DIR=$(cd "$(dirname $0)"; pwd)
readonly DOTFILES_DIR="${THIS_SCRIPT_DIR}/dotfiles"
readonly BASHRC="${HOME}/.bashrc"


function backup() {
    local target="$1"

    local bk
    bk="${target}.bk.$(date +%Y%m%d%H%M%S)"

    if [ -e "${target}" ]; then
        cp "${target}" "${bk}"
    fi
}

function install() {
    cp -r "${DOTFILES_DIR}" "${HOME}/"

    for dot_file in $(find "${DOTFILES_DIR}" -maxdepth 1 -not -name "${DOTFILES_DIR}"); do
        backup "${dot_file}"

        symlink="${HOME}/$(basename ${dot_file})"
        ln -sfvn "${dot_file}" "${symlink}"
    done

}

function main() {
    install
}

main "$@"
