#!/bin/bash

output_dir="./__snapshots__"
limit=5  # Set your limit here (adjust as needed)

# Find all config YAML files in the current directory
# Exclude config.schema.json and any non-config files
config_files=($(find . -maxdepth 1 -name "*.yml" -type f | grep -v "config.schema.json" | sort))

if [ ${#config_files[@]} -eq 0 ]; then
  echo "No config YAML files found in current directory"
  exit 1
fi

echo "Found ${#config_files[@]} config file(s): ${config_files[@]}"

# Create output directory (don't clear it, we'll organize by config name)
mkdir -p "$output_dir"

# Process each config file
for config_file in "${config_files[@]}"; do
  config_name=$(basename "$config_file" .yml)
  temp_dir="./__snapshots_temp_${config_name}"
  config_output_dir="$output_dir/$config_name"
  
  echo ""
  echo "Processing $config_file..."
  
  # Render templates for this config
  python3 render.py -c "$config_file" -o "$temp_dir"
  
  # Get sorted list of directories for this config
  dirs=($(find "$temp_dir" -mindepth 1 -maxdepth 1 -type d | sort))
  total=${#dirs[@]}
  
  if [ $total -eq 0 ]; then
    echo "  No directories generated for $config_file, skipping..."
    rm -rf "$temp_dir"
    continue
  fi
  
  echo "  Generated $total directories"
  
  # Clear this config's output directory
  if [ -d "$config_output_dir" ]; then
    rm -rf "$config_output_dir"
  fi
  mkdir -p "$config_output_dir"
  
  # Take a sample from this config's output
  sampled_count=0
  
  if [ $total -gt $limit ]; then
    # Calculate step to spread the selection
    step=$(awk "BEGIN { print ($total-1)/($limit-1) }")
    keep_indices=()
    for ((i=0; i<$limit; i++)); do
      idx=$(awk "BEGIN {printf \"%d\", ($i*$step + 0.5)}")
      keep_indices+=($idx)
    done

    # Ensure indices are unique and valid
    keeps=()
    for idx in "${keep_indices[@]}"; do
      if [ $idx -ge 0 ] && [ $idx -lt $total ]; then
        dir_to_add="${dirs[$idx]}"
        # Check if this directory is already in keeps
        already_added=0
        for k in "${keeps[@]}"; do
          if [ "$dir_to_add" == "$k" ]; then
            already_added=1
            break
          fi
        done
        if [ $already_added -eq 0 ]; then
          keeps+=("$dir_to_add")
        fi
      fi
    done

    # Copy sampled directories to config-specific output directory
    for k in "${keeps[@]}"; do
      dir_name=$(basename "$k")
      cp -r "$k" "$config_output_dir/"
      echo "  ✓ Sampled: $dir_name"
      ((sampled_count++))
    done
  else
    # If total is less than or equal to limit, copy all
    for d in "${dirs[@]}"; do
      dir_name=$(basename "$d")
      cp -r "$d" "$config_output_dir/"
      echo "  ✓ Included: $dir_name"
      ((sampled_count++))
    done
  fi
  
  echo "  Summary: $sampled_count directories in $config_output_dir"
  
  # Clean up temp directory
  rm -rf "$temp_dir"
done

echo ""
echo "✓ Snapshot generation complete. Output in $output_dir"