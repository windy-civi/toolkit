#!/bin/bash
# Generate Rust and Python types/parsers from OpenAPI specs
# Recursively finds *data.json files and transforms them to OpenAPI, then generates code
# Uses OpenAPI Generator via Docker: https://openapi-generator.tech/docs/installation
# Requires: Docker, Rust

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Check for Docker
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is required but not found."
    echo "Please install Docker (https://www.docker.com)"
    exit 1
fi

# Get input folder (default to schemas if not provided)
INPUT_FOLDER="${1:-${PROJECT_ROOT}/schemas}"

if [ ! -d "$INPUT_FOLDER" ]; then
    echo "Error: Input folder not found: $INPUT_FOLDER"
    echo "Usage: $0 [input_folder]"
    exit 1
fi

# Build the Rust tool first
echo "🔨 Building gov-data-to-openapi..."
cd "${SCRIPT_DIR}/gov-data-to-openapi"
cargo build --release
GOV_DATA_TO_OPENAPI="${SCRIPT_DIR}/gov-data-to-openapi/target/release/gov-data-to-openapi"
cd "$PROJECT_ROOT"

# Find all *data.json files recursively
echo "🔍 Searching for *data.json files in: $INPUT_FOLDER"
DATA_FILES=($(find "$INPUT_FOLDER" -type f -name "*data.json"))

if [ ${#DATA_FILES[@]} -eq 0 ]; then
    echo "Error: No *data.json files found in $INPUT_FOLDER"
    exit 1
fi

echo "Found ${#DATA_FILES[@]} data.json file(s):"
for file in "${DATA_FILES[@]}"; do
    echo "  - $file"
done
echo ""

# Clean up generated folders to ensure fresh generation
echo "🧹 Cleaning up existing generated folders..."
for data_file in "${DATA_FILES[@]}"; do
    data_dir="$(dirname "$data_file")"
    generated_dir="${data_dir}/generated"
    
    if [ -d "$generated_dir" ]; then
        echo "Removing: $generated_dir"
        rm -rf "$generated_dir"
    fi
done
echo ""

# Transform each data.json file to OpenAPI
echo "🔄 Transforming data.json files to OpenAPI specs..."
for data_file in "${DATA_FILES[@]}"; do
    data_dir="$(dirname "$data_file")"
    output_file="${data_dir}/generated/openapi.yaml"
    
    echo "Processing: $data_file"
    "$GOV_DATA_TO_OPENAPI" transform --input "$data_file" --output "$output_file"
    echo ""
done

# Generate code for each OpenAPI spec
for data_file in "${DATA_FILES[@]}"; do
    data_dir="$(dirname "$data_file")"
    openapi_spec="${data_dir}/generated/openapi.yaml"
    generated_dir="${data_dir}/generated"
    
    if [ ! -f "$openapi_spec" ]; then
        echo "⚠️  Skipping $data_file: openapi.yaml not found"
        continue
    fi
    
    echo "📄 Generating code from: $openapi_spec"
    echo ""
    
    OPENAPI_REL_PATH="${openapi_spec#$PROJECT_ROOT/}"
    RUST_OUT_REL_PATH="${generated_dir#$PROJECT_ROOT/}/rust"
    PYTHON_OUT_REL_PATH="${generated_dir#$PROJECT_ROOT/}/python"
    TS_OUT_REL_PATH="${generated_dir#$PROJECT_ROOT/}/typescript"
    
    IGNORE_FILE="${generated_dir}/.openapi-generator-ignore"
    IGNORE_ARG=""
    if [ -f "$IGNORE_FILE" ]; then
        IGNORE_REL_PATH="${IGNORE_FILE#$PROJECT_ROOT/}"
        IGNORE_ARG="--ignore-file-override /local/${IGNORE_REL_PATH}"
    fi
    
    # Generate Rust code (models only)
    echo "📦 Generating Rust types..."
    docker run --rm \
        -v "${PROJECT_ROOT}:/local" \
        -u "$(id -u):$(id -g)" \
        openapitools/openapi-generator-cli generate \
        -i "/local/${OPENAPI_REL_PATH}" \
        -g rust \
        -o "/local/${RUST_OUT_REL_PATH}" \
        --skip-validate-spec \
        --global-property=models,supportingFiles,modelDocs=false,modelTests=false,apiDocs=false,apiTests=false \
        $IGNORE_ARG \
        --additional-properties=packageName=legislative_data_api,packageVersion=1.0.0
    echo "✅ Rust code generated in ${generated_dir}/rust"
    echo ""
    
    # Generate Python code (models only)
    echo "🐍 Generating Python types..."
    docker run --rm \
        -v "${PROJECT_ROOT}:/local" \
        -u "$(id -u):$(id -g)" \
        openapitools/openapi-generator-cli generate \
        -i "/local/${OPENAPI_REL_PATH}" \
        -g python \
        -o "/local/${PYTHON_OUT_REL_PATH}" \
        --skip-validate-spec \
        --global-property=models,supportingFiles,modelDocs=false,modelTests=false,apiDocs=false,apiTests=false \
        $IGNORE_ARG \
        --additional-properties=packageName=legislative_data_api,packageVersion=1.0.0,packageUrl=https://github.com/windy-civi/toolkit
    echo "✅ Python code generated in ${generated_dir}/python"
    echo ""
    
    # Generate TypeScript code (models only)
    echo "📘 Generating TypeScript types..."
    docker run --rm \
        -v "${PROJECT_ROOT}:/local" \
        -u "$(id -u):$(id -g)" \
        openapitools/openapi-generator-cli generate \
        -i "/local/${OPENAPI_REL_PATH}" \
        -g typescript-axios \
        -o "/local/${TS_OUT_REL_PATH}" \
        --skip-validate-spec \
        --global-property=models,supportingFiles,modelDocs=false,modelTests=false,apiDocs=false,apiTests=false \
        $IGNORE_ARG \
        --additional-properties=packageName=legislative-data-api,packageVersion=1.0.0,npmName=@windy-civi/legislative-data-api
    
    echo "✅ TypeScript code generated in ${generated_dir}/typescript"
    echo ""
    
    # Fix permissions on generated files (Docker may create them as root)
    if [ -d "$generated_dir" ]; then
        chmod -R u+w "$generated_dir" 2>/dev/null || true
        # Try to fix ownership if we have sudo (CI environments)
        if command -v sudo &> /dev/null && [ -n "$SUDO_USER" ] || [ "$(id -u)" = "0" ]; then
            chown -R "$(id -u):$(id -g)" "$generated_dir" 2>/dev/null || true
        fi
    fi
    
    # Post-process: Clean up index files to only export models
    echo "🧹 Cleaning up index files..."
    
    # TypeScript: Only export models
    if [ -f "${generated_dir}/typescript/index.ts" ]; then
        # Remove file first to avoid permission issues
        rm -f "${generated_dir}/typescript/index.ts"
        # Extract model names from the generated API file
        # This is a simplified version - you may need to adjust based on actual generated structure
        cat > "${generated_dir}/typescript/index.ts" << 'EOF'
/* tslint:disable */
/* eslint-disable */
/**
 * Legislative Data API
 * 
 * NOTE: This class is auto generated by OpenAPI Generator (https://openapi-generator.tech).
 * https://openapi-generator.tech
 * Do not edit the class manually.
 */

// Export model types only
export type { BillActionLogs } from './api';
export type { BillMetadata } from './api';
export type { BillMetadataAbstractsInner } from './api';
export type { BillMetadataOtherTitlesInner } from './api';
export type { BillMetadataProcessing } from './api';
export type { BillVoteEventLogs } from './api';
EOF
    fi
    
    # Rust: Remove API module from lib.rs
    if [ -f "${generated_dir}/rust/src/lib.rs" ]; then
        rm -f "${generated_dir}/rust/src/lib.rs"
        cat > "${generated_dir}/rust/src/lib.rs" << 'EOF'
#![allow(unused_imports)]
#![allow(clippy::too_many_arguments)]

extern crate serde_repr;
extern crate serde;
extern crate serde_json;

pub mod models;
EOF
    fi
    
    # Python: Clean up __init__.py to only export models
    if [ -f "${generated_dir}/python/legislative_data_api/__init__.py" ]; then
        rm -f "${generated_dir}/python/legislative_data_api/__init__.py"
        cat > "${generated_dir}/python/legislative_data_api/__init__.py" << 'EOF'
# coding: utf-8

# flake8: noqa

"""
    Legislative Data API

    Generated by OpenAPI Generator (https://openapi-generator.tech)

    Do not edit the class manually.
"""  # noqa: E501


__version__ = "1.0.0"

# import models into sdk package
from legislative_data_api.models.bill_action_logs import BillActionLogs as BillActionLogs
from legislative_data_api.models.bill_metadata import BillMetadata as BillMetadata
from legislative_data_api.models.bill_metadata_abstracts_inner import BillMetadataAbstractsInner as BillMetadataAbstractsInner
from legislative_data_api.models.bill_metadata_other_titles_inner import BillMetadataOtherTitlesInner as BillMetadataOtherTitlesInner
from legislative_data_api.models.bill_metadata_processing import BillMetadataProcessing as BillMetadataProcessing
from legislative_data_api.models.bill_vote_event_logs import BillVoteEventLogs as BillVoteEventLogs

__all__ = [
    "BillActionLogs",
    "BillMetadata",
    "BillMetadataAbstractsInner",
    "BillMetadataOtherTitlesInner",
    "BillMetadataProcessing",
    "BillVoteEventLogs",
]
EOF
    fi
    
    echo "✅ Cleanup complete for ${data_file}!"
    echo ""
done

echo "🎉 Code generation complete!"
echo ""
echo "Processed ${#DATA_FILES[@]} data.json file(s) and generated code for each."
