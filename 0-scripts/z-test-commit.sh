#!/bin/bash

DEBUG_MODE=0
COMMIT_MSG=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --debug)
            DEBUG_MODE=1
            ;;
        *)
            COMMIT_MSG+=("$1")
            echo "Added to COMMIT_MSG: $1"
            echo "Current COMMIT_MSG array: ${COMMIT_MSG[@]}"
            ;;
    esac
    shift
done

echo "FINAL COMMIT MESSAGE: ${COMMIT_MSG[*]}"
echo "DEBUG MODE: $DEBUG_MODE"

