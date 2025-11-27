use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use regex::Regex;
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::fs;
use std::path::{Path, PathBuf};

// ============================================================================
// Types
// ============================================================================

#[derive(Debug, Deserialize, Serialize)]
pub struct Catalog {
    #[serde(rename = "@context")]
    pub context: String,
    #[serde(rename = "@type")]
    pub type_: String,
    #[serde(rename = "conformsTo")]
    pub conforms_to: String,
    pub dataset: Vec<Dataset>,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct Dataset {
    pub identifier: String,
    pub title: String,
    pub description: String,
    pub keyword: Vec<String>,
    pub modified: String,
    pub publisher: Publisher,
    #[serde(rename = "contactPoint")]
    pub contact_point: ContactPoint,
    #[serde(rename = "accessLevel")]
    pub access_level: String,
    #[serde(rename = "x-filesystem-path")]
    pub filesystem_path: Option<String>,
    #[serde(rename = "x-path-parameters")]
    pub path_parameters: Option<Vec<PathParameter>>,
    #[serde(rename = "x-file-extensions")]
    pub file_extensions: Option<Vec<String>>,
    #[serde(rename = "x-schema-file")]
    pub schema_file: Option<String>,
    pub temporal: Option<String>,
    pub spatial: Option<String>,
    pub theme: Option<Vec<String>>,
    pub license: Option<String>,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct Publisher {
    #[serde(rename = "@type")]
    pub type_: String,
    pub name: String,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct ContactPoint {
    #[serde(rename = "@type")]
    pub type_: String,
    #[serde(rename = "fn")]
    pub fn_: String,
    #[serde(rename = "hasEmail")]
    pub has_email: String,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct PathParameter {
    pub name: String,
    #[serde(rename = "in")]
    pub in_: String,
    pub required: bool,
    pub schema: ParameterSchema,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct ParameterSchema {
    #[serde(rename = "type")]
    pub type_: String,
    pub pattern: Option<String>,
    pub description: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct OpenApiDocument {
    pub openapi: String,
    pub info: Info,
    pub paths: BTreeMap<String, PathItem>,
    pub components: Option<Components>,
}

#[derive(Debug, Serialize)]
pub struct Info {
    pub title: String,
    pub version: String,
    pub description: Option<String>,
    pub contact: Option<Contact>,
}

#[derive(Debug, Serialize)]
pub struct Contact {
    pub name: String,
    pub email: String,
}

#[derive(Debug, Serialize)]
pub struct PathItem {
    pub summary: Option<String>,
    pub description: Option<String>,
    pub get: Option<Operation>,
}

#[derive(Debug, Serialize)]
pub struct Operation {
    #[serde(rename = "operationId")]
    pub operation_id: String,
    pub summary: String,
    pub description: Option<String>,
    pub parameters: Vec<Parameter>,
    pub responses: BTreeMap<String, Response>,
}

#[derive(Debug, Serialize)]
pub struct Parameter {
    pub name: String,
    #[serde(rename = "in")]
    pub in_: String,
    pub required: bool,
    pub schema: Schema,
    pub description: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct Response {
    pub description: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub content: Option<BTreeMap<String, MediaType>>,
}

#[derive(Debug, Serialize)]
pub struct MediaType {
    pub schema: SchemaRef,
}

#[derive(Debug, Serialize)]
pub struct SchemaRef {
    #[serde(rename = "$ref")]
    pub ref_: String,
}

#[derive(Debug, Serialize)]
pub struct Components {
    pub schemas: BTreeMap<String, Schema>,
}

#[derive(Debug, Serialize)]
pub struct Schema {
    #[serde(rename = "type")]
    pub type_: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub properties: Option<BTreeMap<String, Schema>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub required: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub items: Option<Box<Schema>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub format: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pattern: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub nullable: Option<bool>,
}

// ============================================================================
// Parser
// ============================================================================

#[derive(Debug)]
struct ParsedPattern {
    directory_path: String,
    filename_part: String,
    extension_part: String,
    dir_params: Vec<String>,
    file_params: Vec<String>,
    extension_params: Vec<String>,
}

fn parse_file_pattern(pattern: &str) -> Result<ParsedPattern> {
    let (dir_path, filename) = match pattern.rfind('/') {
        Some(pos) => (&pattern[..pos], &pattern[pos + 1..]),
        None => ("", pattern),
    };

    let (file_part, ext_part) = match filename.find('.') {
        Some(pos) => (&filename[..pos], &filename[pos + 1..]),
        None => (filename, ""),
    };

    let param_regex = Regex::new(r"\{([^}]+)\}")?;

    let dir_params: Vec<String> = param_regex
        .captures_iter(dir_path)
        .map(|cap| cap[1].to_string())
        .collect();

    let file_params: Vec<String> = param_regex
        .captures_iter(file_part)
        .map(|cap| cap[1].to_string())
        .collect();

    let extension_params: Vec<String> = param_regex
        .captures_iter(ext_part)
        .map(|cap| cap[1].to_string())
        .collect();

    Ok(ParsedPattern {
        directory_path: dir_path.to_string(),
        filename_part: file_part.to_string(),
        extension_part: ext_part.to_string(),
        dir_params,
        file_params,
        extension_params,
    })
}

fn to_openapi_path(pattern: &str) -> Result<String> {
    let parsed = parse_file_pattern(pattern)?;
    let path = if parsed.directory_path.is_empty() {
        format!("/{}", parsed.filename_part)
    } else {
        format!("/{}/{}", parsed.directory_path, parsed.filename_part)
    };
    Ok(path)
}

fn parse_extension(ext_part: &str) -> Vec<String> {
    if ext_part.contains('{') {
        vec!["json".to_string(), "xml".to_string(), "csv".to_string()]
    } else if !ext_part.is_empty() {
        vec![ext_part.to_string()]
    } else {
        vec![]
    }
}

// ============================================================================
// Schema Loader
// ============================================================================

fn load_json_schema(schema_path: &Path) -> Result<serde_json::Value> {
    let content = std::fs::read_to_string(schema_path)
        .with_context(|| format!("Failed to read schema file: {}", schema_path.display()))?;
    let schema: serde_json::Value = serde_json::from_str(&content)
        .with_context(|| format!("Failed to parse JSON schema: {}", schema_path.display()))?;
    Ok(schema)
}

// ============================================================================
// Transformer
// ============================================================================

fn transform_catalog(catalog: &Catalog, base_dir: Option<&Path>) -> Result<OpenApiDocument> {
    let info = Info {
        title: "Legislative Data API".to_string(),
        version: "1.0.0".to_string(),
        description: Some(format!("API for {} datasets", catalog.dataset.len())),
        contact: catalog.dataset.first().map(|ds| Contact {
            name: ds.contact_point.fn_.clone(),
            email: ds.contact_point.has_email.replace("mailto:", ""),
        }),
    };

    let mut paths = BTreeMap::new();
    let mut schemas = BTreeMap::new();

    // Sort datasets by identifier for deterministic processing
    let mut sorted_datasets: Vec<_> = catalog.dataset.iter().collect();
    sorted_datasets.sort_by_key(|d| &d.identifier);

    for dataset in sorted_datasets {
        if let Some(ref fs_path) = dataset.filesystem_path {
            let openapi_path = to_openapi_path(fs_path)?;
            let parsed = parse_file_pattern(fs_path)?;
            let extensions = parse_extension(&parsed.extension_part);
            let path_item = create_path_item(dataset, &extensions)?;
            paths.insert(openapi_path, path_item);

            let schema =
                if let (Some(schema_file_path), Some(base)) = (&dataset.schema_file, base_dir) {
                    let schema_path = base.join(schema_file_path);
                    if schema_path.exists() {
                        println!("  Loading schema from: {}", schema_path.display());
                        load_schema_from_file(&schema_path, dataset)?
                    } else {
                        eprintln!(
                            "  Warning: Schema file '{}' not found, using default",
                            schema_path.display()
                        );
                        create_schema(dataset)
                    }
                } else if let Some(schema_file_path) = &dataset.schema_file {
                    let schema_path = Path::new(schema_file_path);
                    if schema_path.exists() {
                        println!("  Loading schema from: {}", schema_path.display());
                        load_schema_from_file(schema_path, dataset)?
                    } else {
                        eprintln!(
                            "  Warning: Schema file '{}' not found, using default",
                            schema_path.display()
                        );
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

    let mut content = BTreeMap::new();
    for ext in extensions {
        let media_type = extension_to_media_type(ext);
        content.insert(
            media_type,
            MediaType {
                schema: SchemaRef {
                    ref_: format!(
                        "#/components/schemas/{}",
                        dataset.identifier.replace('-', "_")
                    ),
                },
            },
        );
    }

    let mut responses = BTreeMap::new();
    // Insert in sorted order: 200 before 404
    responses.insert(
        "200".to_string(),
        Response {
            description: "Successful response".to_string(),
            content: Some(content),
        },
    );
    responses.insert(
        "404".to_string(),
        Response {
            description: "Not found".to_string(),
            content: None,
        },
    );

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
    let mut properties = BTreeMap::new();

    properties.insert(
        "identifier".to_string(),
        Schema {
            type_: "string".to_string(),
            description: Some("Unique identifier".to_string()),
            properties: None,
            required: None,
            items: None,
            format: None,
            pattern: None,
            nullable: None,
        },
    );

    properties.insert(
        "title".to_string(),
        Schema {
            type_: "string".to_string(),
            description: Some("Title".to_string()),
            properties: None,
            required: None,
            items: None,
            format: None,
            pattern: None,
            nullable: None,
        },
    );

    properties.insert(
        "description".to_string(),
        Schema {
            type_: "string".to_string(),
            description: Some("Description".to_string()),
            properties: None,
            required: None,
            items: None,
            format: None,
            pattern: None,
            nullable: None,
        },
    );

    properties.insert(
        "keywords".to_string(),
        Schema {
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
        },
    );

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
    }
    .to_string()
}

fn load_schema_from_file(schema_path: &Path, dataset: &Dataset) -> Result<Schema> {
    let json_schema = load_json_schema(schema_path)
        .with_context(|| format!("Failed to load schema from {}", schema_path.display()))?;

    let description = json_schema
        .get("description")
        .and_then(|v| v.as_str())
        .map(|s| s.to_string())
        .or_else(|| Some(dataset.description.clone()));

    let mut properties = BTreeMap::new();
    let mut required = Vec::new();

    // Sort properties by key for deterministic ordering
    if let Some(props) = json_schema.get("properties").and_then(|v| v.as_object()) {
        let mut sorted_props: Vec<_> = props.iter().collect();
        sorted_props.sort_by_key(|(k, _)| *k);
        for (key, value) in sorted_props {
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
        properties: if properties.is_empty() {
            None
        } else {
            Some(properties)
        },
        required: if required.is_empty() {
            None
        } else {
            Some(required)
        },
        items: None,
        description,
        format: None,
        pattern: None,
        nullable: None,
    })
}

fn convert_json_schema_property(prop: &serde_json::Value) -> Option<Schema> {
    let (type_, nullable) = if let Some(type_val) = prop.get("type") {
        if let Some(type_array) = type_val.as_array() {
            let non_null_types: Vec<&str> = type_array
                .iter()
                .filter_map(|v| v.as_str())
                .filter(|s| *s != "null")
                .collect();

            if type_array.iter().any(|v| v.as_str() == Some("null")) && !non_null_types.is_empty() {
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

    let description = prop
        .get("description")
        .and_then(|v| v.as_str())
        .map(|s| s.to_string());
    let format = prop
        .get("format")
        .and_then(|v| v.as_str())
        .map(|s| s.to_string());
    let pattern = prop
        .get("pattern")
        .and_then(|v| v.as_str())
        .map(|s| s.to_string());

    let (properties, items) = if type_ == "object" {
        let mut props = BTreeMap::new();
        if let Some(obj_props) = prop.get("properties").and_then(|v| v.as_object()) {
            // Sort properties by key for deterministic ordering
            let mut sorted_props: Vec<_> = obj_props.iter().collect();
            sorted_props.sort_by_key(|(k, _)| *k);
            for (key, value) in sorted_props {
                if let Some(schema) = convert_json_schema_property(value) {
                    props.insert(key.clone(), schema);
                }
            }
        }
        (if props.is_empty() { None } else { Some(props) }, None)
    } else if type_ == "array" {
        let item_schema = prop
            .get("items")
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

// ============================================================================
// CLI
// ============================================================================

#[derive(Parser)]
#[command(name = "gov-data-to-openapi")]
#[command(about = "Convert Project Open Data catalogs to OpenAPI specs", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Transform data.json to OpenAPI YAML
    Transform {
        /// Input data.json file
        #[arg(short, long, default_value = "data.json")]
        input: PathBuf,

        /// Output openapi.yaml file
        #[arg(short, long, default_value = "openapi.yaml")]
        output: PathBuf,
    },

    /// Validate data.json structure
    Validate {
        /// Input data.json file
        #[arg(short, long, default_value = "data.json")]
        input: PathBuf,
    },
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Transform { input, output } => {
            transform_command(input, output)?;
        }
        Commands::Validate { input } => {
            validate_command(input)?;
        }
    }

    Ok(())
}

fn transform_command(input: PathBuf, mut output: PathBuf) -> Result<()> {
    if let Some(input_parent) = input.parent() {
        if input_parent.file_name() == Some(std::ffi::OsStr::new("schemas")) {
            if output == PathBuf::from("openapi.yaml") {
                output = input_parent.join("generated").join("openapi.yaml");
            }
        }
    }

    if let Some(output_parent) = output.parent() {
        fs::create_dir_all(output_parent)?;
    }

    println!("Transforming: {} → {}", input.display(), output.display());

    let json_data = fs::read_to_string(&input)?;
    let catalog: Catalog = serde_json::from_str(&json_data)?;

    println!("Found {} datasets\n", catalog.dataset.len());

    let base_dir = input.parent().and_then(|p| {
        if p.file_name() == Some(std::ffi::OsStr::new("schemas")) {
            p.parent()
        } else {
            Some(p)
        }
    });

    let openapi_doc = transform_catalog(&catalog, base_dir)?;

    let yaml_data = serde_yaml::to_string(&openapi_doc)?;
    fs::write(&output, yaml_data)?;

    println!("✅ Transformation complete!");
    println!("\nOpenAPI Document Summary:");
    println!("  Version: {}", openapi_doc.openapi);
    println!("  Title: {}", openapi_doc.info.title);
    println!("  Paths: {}", openapi_doc.paths.len());

    if let Some(ref components) = openapi_doc.components {
        println!("  Schemas: {}", components.schemas.len());
    }

    println!("\nGenerated paths:");
    for path in openapi_doc.paths.keys() {
        println!("  GET {}", path);
    }

    println!("\n📄 Output written to: {}", output.display());

    Ok(())
}

fn validate_command(input: PathBuf) -> Result<()> {
    println!("Validating: {}\n", input.display());

    let json_data = fs::read_to_string(&input)?;
    let catalog: Catalog = serde_json::from_str(&json_data)?;

    println!("✅ Valid Project Open Data catalog");
    println!("  Datasets: {}", catalog.dataset.len());

    for (i, dataset) in catalog.dataset.iter().enumerate() {
        println!("\n  Dataset {} - {}", i + 1, dataset.identifier);
        println!("    Title: {}", dataset.title);

        if let Some(ref path) = dataset.filesystem_path {
            println!("    Filesystem path: {}", path);

            let parsed = parse_file_pattern(path)?;
            let all_params: Vec<String> = parsed
                .dir_params
                .iter()
                .chain(parsed.file_params.iter())
                .chain(parsed.extension_params.iter())
                .cloned()
                .collect();
            println!("    Parameters: {:?}", all_params);
            if !parsed.extension_part.is_empty() {
                println!("    Extension: .{}", parsed.extension_part);
            }
        } else {
            println!("    ⚠️  No x-filesystem-path defined");
        }
    }

    Ok(())
}
