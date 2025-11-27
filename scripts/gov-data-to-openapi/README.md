# Project Open Data to OpenAPI Converter

Does 2 things:

- Converts Project Open Data `data.json` catalogs to OpenAPI 3.1 YAML specifications, enabling you to leverage the entire OpenAPI ecosystem for type generation and validation.
- Extends `data.json` with path validators that pass down to `openapi`, allowing you to define path schemas with validation util generation.

## Architecture

```
data.json (Project Open Data)
         ↓
    Rust Converter
         ↓
   openapi.yaml
         ↓
    ┌────┴────┬────────┬──────────┐
    ↓         ↓        ↓          ↓
TypeScript  Python   Rust      Validators
 Types     Types    Types
```

### Examples

```
{bill_id}-{title}/logs/{timestamp}.voteevent.json
data/{jurisdiction}/{session}/bills/{bill_id}.{format}
archive/{year}/{month}/{day}/{id}.json
bills/{bill_id}/votes/{timestamp}.{schema}.json
```
