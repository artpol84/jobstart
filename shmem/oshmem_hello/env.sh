#!/bin/bash

OMPI_BASE_RELEASE=<release-path>
OMPI_BASE_DEBUG=<debug-path>
TEST_SYMKEY_SIZE=500M

function test_set_release()
{
    PATH=${OMPI_BASE_RELEASE}/bin:$PATH
    LD_LIBRARY_PATH=${OMPI_BASE_RELEASE}/lib:$LD_LIBRARY_PATH
}

function test_set_debug()
{
    PATH=${OMPI_BASE_DEBUG}/bin:$PATH
    LD_LIBRARY_PATH=${OMPI_BASE_DEBUG}/lib:$LD_LIBRARY_PATH
}


test_set_env()
{
    test_env_type="$1"
    if [ -z "$type" ]; then
        test_env_type="release"
        echo "Distrib type wasn't specified, use \"release\""
    fi

    case "$test_env_type" in
        "release")
            test_set_release
            ;;
        "debug")
            test_set_debug
            ;;
        *)
            echo "Bad distribution type \"$test_env_type\""
            exit 1
            ;;
    esac
}
