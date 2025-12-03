# ✏️{ locale.name }✏️ Scraper Test Repository

**Testing repository for OpenStates scraper changes**

## Purpose

This repository allows you to test changes to the [OpenStates scrapers](https://github.com/openstates/openstates-scrapers) before submitting them upstream.

## How to Use

1. **Fork** `openstates/openstates-scrapers`
2. **Create branch** with your fix (e.g., `fix/mo-empty-title`)
3. **Trigger** the "Test OpenStates Scraper" workflow
4. **Provide**:
   - Your GitHub username (fork owner)
   - Branch name with your changes
5. **Review** the test results in the workflow summary

The workflow will build a Docker image from your fork and run the scraper against ✏️{ locale.name }✏️ data without committing results.

## What Gets Tested

- Scraper runs successfully
- Data is extracted
- Summary shows object counts and any errors
- No data is committed (safe testing)

## After Testing

If your test succeeds, submit a PR to `openstates/openstates-scrapers` with your changes!
