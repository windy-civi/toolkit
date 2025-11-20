#!/bin/bash

# PROD DATA SEED: We don't run this script on every test run as it is prod data.

BILL_LIMIT=${BILL_LIMIT:-20}
GIT_DIR="__snapshots__"

function delete_files_dir {
    local child="$1"
    find "$child" -type d -name "files" -exec rm -rf {} +
}

function prune_bills {
    local child="$1"
    # For every 'bills' directory under the repo, keep only the first $BILL_LIMIT subfolders
    while IFS= read -r bills_dir; do
        [ -d "$bills_dir" ] || continue

        local bill_dirs=()
        while IFS= read -r bill_dir; do
            bill_dirs+=("$bill_dir")
        done < <(find "$bills_dir" -mindepth 1 -maxdepth 1 -type d | sort)

        local bill_count=${#bill_dirs[@]}
        if (( bill_count <= BILL_LIMIT )); then
            continue
        fi

        for ((i=BILL_LIMIT; i<bill_count; i++)); do
            local excess_dir="${bill_dirs[i]}"
            if [ -n "$excess_dir" ]; then
                echo "Deleting excess bill folder: $excess_dir"
                rm -rf "$excess_dir"
            fi
        done
    done < <(find "$child" -type d -name "bills")
}

function delete_git_dir {
    local child="$1"
    rm -rf "$child/.git"
}

function clear_snapshot {
    rm -rf "$GIT_DIR"
    mkdir -p "$GIT_DIR"
}

function main {
    # clear_snapshot
    # ./main.sh --git-dir $GIT_DIR usa il

    # For each git repo, do some pruning/cleanup
    for child in "$GIT_DIR"/*; do
    if [ -d "$child" ]; then
        delete_files_dir "$child"
        prune_bills "$child"
        delete_git_dir "$child"
    fi
    done
}

main