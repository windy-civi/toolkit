use crate::types::*;
use crate::parser::{parse_file_pattern, to_openapi_path, parse_extension};
use crate::schema_loader::load_json_schema;
use anyhow::{Result, Context};
use std::collections::HashMap;
use std::path::Path;

pub fn transform_catalog(catalog: &Catalog, base_dir: Option<&Path>) -> Result<OpenApiDocument> {
    let info = Info {
        title: "Legislative Data API".to_string(),
        version: "1.0.0".to_string(),
        description: Some(format!("API for {} datasets", catalog.dataset.len())),
        contact: catalog.dataset.first().map(|ds| Contact {
            name: ds.contact_point.fn_.clone(),
            email: ds.contact_point.has_email.replace("mailto:", ""),
        }),
    };

    let mut paths = HashMap::new();
    let mut schemas = HashMap::new();

    for dataset in &catalog.dataset {
        if let Some(ref fs_path) = dataset.filesystem_path {
            // Convert to OpenAPI path
            let openapi_path = to_openapi_path(fs_path)?;

            // Parse pattern for extensions
            let parsed = parse_file_pattern(fs_path)?;
            let extensions = parse_extension(&parsed.extension_part);

            // Create path item with operation
            let path_item = create_path_item(dataset, &extensions)?;
            paths.insert(openapi_path, path_item);

            // Create schema - try to load from schema file if x-schema-file is specified
            let schema = if let (Some(schema_file_path), Some(base)) = 
                (&dataset.schema_file, base_dir) {
                let schema_path = base.join(schema_file_path);
                if schema_path.exists() {
                    println!("  Loading schema from: {}", schema_path.display());
                    // Load and convert JSON schema to OpenAPI schema
                    load_schema_from_file(&schema_path, dataset)?
                } else {
                    eprintln!("  Warning: Schema file '{}' not found, using default", schema_path.display());
                    create_schema(dataset)
                }
            } else if let Some(schema_file_path) = &dataset.schema_file {
                // Try relative to current working directory if no base_dir
                let schema_path = Path::new(schema_file_path);
                if schema_path.exists() {
                    println!("  Loading schema from: {}", schema_path.display());
                    load_schema_from_file(schema_path, dataset)?
                } else {
                    eprintln!("  Warning: Schema file '{}' not found, using default", schema_path.display());
                    create_schema(dataset)
                }
            } else {
                create_schema(dataset)
            };
            schemas.insert(dataset.identifier.replace('-', "_"), schema);
        }
    }

    Ok(OpenApiDocument {
        openapi: "3.0.3".to_string(),
        info,
        paths,
        components: Some(Components { schemas }),
    })
}

fn create_path_item(dataset: &Dataset, extensions: &[String]) -> Result<PathItem> {
    let mut parameters = Vec::new();

    // Add path parameters from dataset
    if let Some(ref params) = dataset.path_parameters {
        for param in params {
            let schema = Schema {
                type_: param.schema.type_.clone(),
                properties: None,
                required: None,
                items: None,
                description: param.schema.description.clone(),
                format: None,
                pattern: param.schema.pattern.clone(),
                nullable: None,
            };
            parameters.push(Parameter {
                name: param.name.clone(),
                in_: param.in_.clone(),
                required: param.required,
                schema,
                description: param.schema.description.clone(),
            });
        }
    }

    // Add format parameter if multiple extensions
    if extensions.len() > 1 {
        parameters.push(Parameter {
            name: "format".to_string(),
            in_: "query".to_string(),
            required: false,
            schema: Schema {
                type_: "string".to_string(),
                properties: None,
                required: None,
                items: None,
                description: Some("Response format".to_string()),
                format: None,
                pattern: None,
                nullable: None,
            },
            description: Some("Response format".to_string()),
        });
    }

    // Create responses with content types for each extension
    let mut content = HashMap::new();
    for ext in extensions {
        let media_type = extension_to_media_type(ext);
        content.insert(media_type, MediaType {
            schema: SchemaRef {
                ref_: format!("#/components/schemas/{}", dataset.identifier.replace('-', "_")),
            },
        });
    }

    let mut responses = HashMap::new();
    responses.insert("200".to_string(), Response {
        description: "Successful response".to_string(),
        content: Some(content),
    });
    responses.insert("404".to_string(), Response {
        description: "Not found".to_string(),
        content: None,
    });

    let operation = Operation {
        operation_id: format!("get_{}", dataset.identifier.replace('-', "_")),
        summary: dataset.title.clone(),
        description: Some(dataset.description.clone()),
        parameters,
        responses,
    };

    Ok(PathItem {
        summary: Some(dataset.title.clone()),
        description: Some(dataset.description.clone()),
        get: Some(operation),
    })
}

fn create_schema(dataset: &Dataset) -> Schema {
    let mut properties = HashMap::new();

    properties.insert("identifier".to_string(), Schema {
        type_: "string".to_string(),
        description: Some("Unique identifier".to_string()),
        properties: None,
        required: None,
        items: None,
        format: None,
        pattern: None,
        nullable: None,
    });

    properties.insert("title".to_string(), Schema {
        type_: "string".to_string(),
        description: Some("Title".to_string()),
        properties: None,
        required: None,
        items: None,
        format: None,
        pattern: None,
        nullable: None,
    });

    properties.insert("description".to_string(), Schema {
        type_: "string".to_string(),
        description: Some("Description".to_string()),
        properties: None,
        required: None,
        items: None,
        format: None,
        pattern: None,
        nullable: None,
    });

    properties.insert("keywords".to_string(), Schema {
        type_: "array".to_string(),
        description: Some("Keywords".to_string()),
        items: Some(Box::new(Schema {
            type_: "string".to_string(),
            properties: None,
            required: None,
            items: None,
            description: None,
            format: None,
            pattern: None,
            nullable: None,
        })),
        properties: None,
        required: None,
        format: None,
        pattern: None,
        nullable: None,
    });

    Schema {
        type_: "object".to_string(),
        properties: Some(properties),
        required: Some(vec![
            "identifier".to_string(),
            "title".to_string(),
            "description".to_string(),
        ]),
        items: None,
        description: Some(dataset.description.clone()),
        format: None,
        pattern: None,
        nullable: None,
    }
}

fn extension_to_media_type(ext: &str) -> String {
    match ext {
        "json" => "application/json",
        "xml" => "application/xml",
        "csv" => "text/csv",
        "yaml" | "yml" => "application/yaml",
        _ => "application/octet-stream",
    }.to_string()
}

/// Load schema from JSON schema file and convert to OpenAPI schema
fn load_schema_from_file(schema_path: &Path, dataset: &Dataset) -> Result<Schema> {
    let json_schema = load_json_schema(schema_path)
        .with_context(|| format!("Failed to load schema from {}", schema_path.display()))?;
    
    // Extract description from JSON schema
    let description = json_schema.get("description")
        .and_then(|v| v.as_str())
        .map(|s| s.to_string())
        .or_else(|| Some(dataset.description.clone()));
    
    // Convert JSON schema properties to OpenAPI schema
    let mut properties = HashMap::new();
    let mut required = Vec::new();
    
    if let Some(props) = json_schema.get("properties").and_then(|v| v.as_object()) {
        for (key, value) in props {
            if let Some(schema) = convert_json_schema_property(value) {
                properties.insert(key.clone(), schema);
            }
        }
    }
    
    if let Some(req) = json_schema.get("required").and_then(|v| v.as_array()) {
        for item in req {
            if let Some(s) = item.as_str() {
                required.push(s.to_string());
            }
        }
    }
    
    Ok(Schema {
        type_: "object".to_string(),
        properties: if properties.is_empty() { None } else { Some(properties) },
        required: if required.is_empty() { None } else { Some(required) },
        items: None, // items only for array types, not objects
        description,
        format: None,
        pattern: None,
        nullable: None,
    })
}

/// Convert a JSON schema property to OpenAPI schema
fn convert_json_schema_property(prop: &serde_json::Value) -> Option<Schema> {
    // Handle nullable types: ["string", "null"] -> "string" with nullable: true
    let (type_, nullable) = if let Some(type_val) = prop.get("type") {
        if let Some(type_array) = type_val.as_array() {
            // Check if it's a nullable type like ["string", "null"]
            let non_null_types: Vec<&str> = type_array.iter()
                .filter_map(|v| v.as_str())
                .filter(|s| *s != "null")
                .collect();
            
            if type_array.iter().any(|v| v.as_str() == Some("null")) && !non_null_types.is_empty() {
                // It's nullable - use the first non-null type
                (non_null_types[0].to_string(), Some(true))
            } else if let Some(type_str) = type_val.as_str() {
                (type_str.to_string(), None)
            } else if !non_null_types.is_empty() {
                (non_null_types[0].to_string(), None)
            } else {
                return None;
            }
        } else if let Some(type_str) = type_val.as_str() {
            (type_str.to_string(), None)
        } else {
            return None;
        }
    } else {
        return None;
    };
    
    let description = prop.get("description")
        .and_then(|v| v.as_str())
        .map(|s| s.to_string());
    let format = prop.get("format")
        .and_then(|v| v.as_str())
        .map(|s| s.to_string());
    let pattern = prop.get("pattern")
        .and_then(|v| v.as_str())
        .map(|s| s.to_string());
    
    let (properties, items) = if type_ == "object" {
        let mut props = HashMap::new();
        if let Some(obj_props) = prop.get("properties").and_then(|v| v.as_object()) {
            for (key, value) in obj_props {
                if let Some(schema) = convert_json_schema_property(value) {
                    props.insert(key.clone(), schema);
                }
            }
        }
        (if props.is_empty() { None } else { Some(props) }, None)
    } else if type_ == "array" {
        let item_schema = prop.get("items")
            .and_then(|v| convert_json_schema_property(v))
            .map(Box::new);
        (None, item_schema)
    } else {
        (None, None)
    };
    
    Some(Schema {
        type_,
        properties,
        required: None,
        items,
        description,
        format,
        pattern,
        nullable,
    })
}

