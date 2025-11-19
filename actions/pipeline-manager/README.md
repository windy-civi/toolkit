Tools to manage the potentially 100s or 10s of 1000s of repos inside `windy-civi-pipelines`.

## Template System

This directory includes a template rendering system that generates files for each locale based on `config.yml`. Uses bash and standard tools - no pip installs required!

### Usage

Render templates for all managed locales:

```bash
./render.sh [output_directory]
```

By default, rendered files are written to `generated/` directory, organized by locale:

```
generated/
  al/
    workflow.yml
    ...
  ak/
    workflow.yml
    ...
```

### Template Variables

In your template files, you can use the following variables:

- `✏️✏️ locale ✏️✏️` - The locale code (e.g., 'al', 'ak', 'az')
- `✏️✏️ toolkit_branch ✏️✏️` - The toolkit branch (defaults to 'main')
- `✏️✏️ managed ✏️✏️` - Whether the locale is managed (boolean)
- Any other variables defined in `config.yml` for that locale

### Template Syntax

Templates use simple variable substitution with custom delimiters to avoid conflicts with GitHub Actions syntax (`${{ ... }}`):

- **Variables**: `✏️✏️ variable ✏️✏️` - Replaced with the actual value from config.yml

Example:

```yaml
name: Scrape and Format Data For ✏️✏️ locale ✏️✏️
env:
  STATE_CODE: ✏️✏️ locale ✏️✏️
  TOOLKIT_BRANCH: ✏️✏️ toolkit_branch ✏️✏️
```

**Note**:

- GitHub Actions syntax like `${{ env.STATE_CODE }}` will be left untouched and work correctly in the rendered output.
- This is a simple variable substitution system - for complex logic, use shell scripting or other tools.

### Directory Structure

The template system maintains the exact directory structure from `templates/`:

- `templates/workflow.yml.j2` → `generated/{locale}/workflow.yml`
- `templates/subdir/file.txt.j2` → `generated/{locale}/subdir/file.txt`

### Example

See `templates/openstates-to-ocd-decentralized/workflow.yml.j2` for a complete example template that includes both template variables and GitHub Actions syntax.
