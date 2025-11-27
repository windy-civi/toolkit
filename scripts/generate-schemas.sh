#!/bin/bash
# Generate Rust and Python types/parsers from OpenAPI spec
# Uses OpenAPI Generator: https://openapi-generator.tech/docs/installation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OPENAPI_SPEC="${PROJECT_ROOT}/schemas/generated/openapi.yaml"
GENERATED_DIR="${PROJECT_ROOT}/schemas/generated"

if [ ! -f "$OPENAPI_SPEC" ]; then
    echo "Error: openapi.yaml not found at $OPENAPI_SPEC"
    echo "Please run: pod2openapi transform --input schemas/ocd-files.data.json"
    exit 1
fi

# Check if Java is available, otherwise use Docker
if command -v java &> /dev/null && java -version &> /dev/null; then
    USE_DOCKER=false
    GENERATOR_CMD="npx @openapitools/openapi-generator-cli"
elif command -v docker &> /dev/null; then
    USE_DOCKER=true
    GENERATOR_CMD="docker run --rm -v \"${SCRIPT_DIR}:/local\" openapitools/openapi-generator-cli"
    echo "⚠️  Java not found, using Docker instead"
else
    echo "Error: Neither Java nor Docker is available."
    echo "Please install Java (https://www.java.com) or Docker (https://www.docker.com)"
    exit 1
fi

echo "Generating code from OpenAPI spec: $OPENAPI_SPEC"
echo ""

# Generate Rust code (models only)
echo "📦 Generating Rust types..."
if [ "$USE_DOCKER" = true ]; then
    docker run --rm \
        -v "${PROJECT_ROOT}:/local" \
        openapitools/openapi-generator-cli generate \
        -i /local/schemas/generated/openapi.yaml \
        -g rust \
        -o /local/schemas/generated/rust \
        --skip-validate-spec \
        --global-property=models,supportingFiles,modelDocs=false,modelTests=false,apiDocs=false,apiTests=false \
        --ignore-file-override /local/schemas/generated/.openapi-generator-ignore \
        --additional-properties=packageName=legislative_data_api,packageVersion=1.0.0
else
    npx @openapitools/openapi-generator-cli generate \
        -i "$OPENAPI_SPEC" \
        -g rust \
        -o "${GENERATED_DIR}/rust" \
        --skip-validate-spec \
        --global-property=models,supportingFiles,modelDocs=false,modelTests=false,apiDocs=false,apiTests=false \
        --ignore-file-override /local/schemas/generated/.openapi-generator-ignore \
        --additional-properties=packageName=legislative_data_api,packageVersion=1.0.0
fi

echo "✅ Rust code generated in ${GENERATED_DIR}/rust"
echo ""

# Generate Python code (models only)
echo "🐍 Generating Python types..."
if [ "$USE_DOCKER" = true ]; then
    docker run --rm \
        -v "${PROJECT_ROOT}:/local" \
        openapitools/openapi-generator-cli generate \
        -i /local/schemas/generated/openapi.yaml \
        -g python \
        -o /local/schemas/generated/python \
        --skip-validate-spec \
        --global-property=models,supportingFiles,modelDocs=false,modelTests=false,apiDocs=false,apiTests=false \
        --ignore-file-override /local/schemas/generated/.openapi-generator-ignore \
        --additional-properties=packageName=legislative_data_api,packageVersion=1.0.0,packageUrl=https://github.com/windy-civi/toolkit
else
    npx @openapitools/openapi-generator-cli generate \
        -i "$OPENAPI_SPEC" \
        -g python \
        -o "${GENERATED_DIR}/python" \
        --skip-validate-spec \
        --global-property=models,supportingFiles,modelDocs=false,modelTests=false,apiDocs=false,apiTests=false \
        --ignore-file-override /local/schemas/generated/.openapi-generator-ignore \
        --additional-properties=packageName=legislative_data_api,packageVersion=1.0.0,packageUrl=https://github.com/windy-civi/toolkit
fi

echo "✅ Python code generated in ${GENERATED_DIR}/python"
echo ""

# Generate TypeScript code (models only)
echo "📘 Generating TypeScript types..."
if [ "$USE_DOCKER" = true ]; then
    docker run --rm \
        -v "${PROJECT_ROOT}:/local" \
        openapitools/openapi-generator-cli generate \
        -i /local/schemas/generated/openapi.yaml \
        -g typescript-axios \
        -o /local/schemas/generated/typescript \
        --skip-validate-spec \
        --global-property=models,supportingFiles,modelDocs=false,modelTests=false,apiDocs=false,apiTests=false \
        --ignore-file-override /local/schemas/generated/.openapi-generator-ignore \
        --additional-properties=packageName=legislative-data-api,packageVersion=1.0.0,npmName=@windy-civi/legislative-data-api
else
    npx @openapitools/openapi-generator-cli generate \
        -i "$OPENAPI_SPEC" \
        -g typescript-axios \
        -o "${GENERATED_DIR}/typescript" \
        --skip-validate-spec \
        --global-property=models,supportingFiles,modelDocs=false,modelTests=false,apiDocs=false,apiTests=false \
        --ignore-file-override /local/schemas/generated/.openapi-generator-ignore \
        --additional-properties=packageName=legislative-data-api,packageVersion=1.0.0,npmName=@windy-civi/legislative-data-api
fi

echo "✅ TypeScript code generated in ${GENERATED_DIR}/typescript"
echo ""

# Post-process: Clean up index files to only export models
echo "🧹 Cleaning up index files..."

# TypeScript: Only export models
if [ -f "${GENERATED_DIR}/typescript/index.ts" ]; then
    cat > "${GENERATED_DIR}/typescript/index.ts" << 'EOF'
/* tslint:disable */
/* eslint-disable */
/**
 * Legislative Data API
 * API for 3 datasets
 *
 * The version of the OpenAPI document: 1.0.0
 * Contact: info@chihacknight.org
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
if [ -f "${GENERATED_DIR}/rust/src/lib.rs" ]; then
    cat > "${GENERATED_DIR}/rust/src/lib.rs" << 'EOF'
#![allow(unused_imports)]
#![allow(clippy::too_many_arguments)]

extern crate serde_repr;
extern crate serde;
extern crate serde_json;

pub mod models;
EOF
fi

# Python: Clean up __init__.py to only export models
if [ -f "${GENERATED_DIR}/python/legislative_data_api/__init__.py" ]; then
    cat > "${GENERATED_DIR}/python/legislative_data_api/__init__.py" << 'EOF'
# coding: utf-8

# flake8: noqa

"""
    Legislative Data API

    API for 3 datasets

    The version of the OpenAPI document: 1.0.0
    Contact: info@chihacknight.org
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

echo "✅ Cleanup complete!"
echo ""

echo "🎉 Code generation complete!"
echo ""
echo "Generated code:"
echo "  - Rust:       ${GENERATED_DIR}/rust"
echo "  - Python:     ${GENERATED_DIR}/python"
echo "  - TypeScript: ${GENERATED_DIR}/typescript"

