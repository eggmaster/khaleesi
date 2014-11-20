#!/usr/bin/env bash
set -e -u
main() {
    local tempest_dir=$1
    pushd $tempest_dir
    yum install ./*rpm
    popd
}

main "$@"
