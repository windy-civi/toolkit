#!/bin/bash

output_dir="./__snapshot__"

python3 render.py -o $output_dir

# Keep only a limited number of directories in ./generated, evenly spread out

limit=5  # Set your limit here (adjust as needed)

# Get sorted list of directories only
dirs=($(find "$output_dir" -mindepth 1 -maxdepth 1 -type d | sort))

total=${#dirs[@]}
if [ $total -gt $limit ]; then
  # Calculate step to spread the selection
  step=$(awk "BEGIN { print ($total-1)/($limit-1) }")
  keep_indices=()
  for ((i=0; i<$limit; i++)); do
    idx=$(awk "BEGIN {printf \"%d\", ($i*$step + 0.5)}")
    keep_indices+=($idx)
  done

  # Ensure indices are unique and valid
  declare -A seen
  keeps=()
  for idx in "${keep_indices[@]}"; do
    [ $idx -ge 0 ] && [ $idx -lt $total ] && [ -z "${seen[$idx]}" ] && keeps+=(${dirs[$idx]}) && seen[$idx]=1
  done

  # Delete folders not in keeps
  for d in "${dirs[@]}"; do
    skip=0
    for k in "${keeps[@]}"; do
      if [ "$d" == "$k" ]; then skip=1; break; fi
    done
    if [ $skip -eq 0 ]; then
      rm -rf "$d"
    fi
  done
fi