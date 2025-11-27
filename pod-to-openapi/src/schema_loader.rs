use std::path::Path;
use anyhow::{Result, Context};

/// Load JSON schema file
pub fn load_json_schema(schema_path: &Path) -> Result<serde_json::Value> {
    let content = std::fs::read_to_string(schema_path)
        .with_context(|| format!("Failed to read schema file: {}", schema_path.display()))?;
    
    let schema: serde_json::Value = serde_json::from_str(&content)
        .with_context(|| format!("Failed to parse JSON schema: {}", schema_path.display()))?;
    
    Ok(schema)
}

