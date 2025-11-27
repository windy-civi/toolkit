# Generated Code

This directory contains generated code from the OpenAPI specification.

## Files

- `openapi.yaml` - OpenAPI 3.0.3 specification generated from `ocd-files.data.json`
- `rust/` - Generated Rust types and API client
- `python/` - Generated Python types and API client
- `typescript/` - Generated TypeScript types and API client
- Code generation script is in `../../scripts/generate-schemas.sh`

## Regenerating Code

To regenerate the Rust, Python, and TypeScript code from the OpenAPI spec:

```bash
../../scripts/generate-schemas.sh
```

This script:
1. Uses [OpenAPI Generator](https://openapi-generator.tech/) via Docker (or npm if Java is available)
2. Generates Rust types in `rust/`
3. Generates Python types in `python/`
4. Generates TypeScript types in `typescript/`

## Workflow

1. **Update data.json**: Edit `../ocd-files.data.json` with your Project Open Data catalog
2. **Generate OpenAPI**: Run `pod2openapi transform --input ../ocd-files.data.json`
3. **Generate code**: Run `../../scripts/generate-schemas.sh`

## Generated Code Usage

### Rust

The generated Rust code is in `rust/`. To use it:

```rust
use legislative_data_api::apis::*;
use legislative_data_api::models::*;
```

### Python

The generated Python code is in `python/`. To use it:

```python
from legislative_data_api import ApiClient, Configuration
from legislative_data_api.apis import DefaultApi
```

### TypeScript

The generated TypeScript code is in `typescript/`. To use it:

```typescript
import { DefaultApi, Configuration, BillMetadata } from './typescript';

const config = new Configuration({
  basePath: 'https://api.example.com'
});
const api = new DefaultApi(config);

// Use the API
const metadata = await api.getBillMetadata({
  jurisdiction: 'wy',
  session: '2024',
  billId: 'SF0001',
  title: 'example-bill'
});
```

## Requirements

- Docker (or Java + npm for OpenAPI Generator)
- The `pod2openapi` tool from `../../pod-to-openapi/`

