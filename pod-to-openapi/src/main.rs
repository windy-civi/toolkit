use anyhow::Result;
use clap::{Parser, Subcommand};
use std::fs;
use std::path::PathBuf;

mod parser;
mod schema_loader;
mod transformer;
mod types;

use transformer::transform_catalog;
use types::Catalog;

#[derive(Parser)]
#[command(name = "pod2openapi")]
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
    // If input is in schemas/ and output is default, put it in schemas/generated/
    if let Some(input_parent) = input.parent() {
        if input_parent.file_name() == Some(std::ffi::OsStr::new("schemas")) {
            if output == PathBuf::from("openapi.yaml") {
                output = input_parent.join("generated").join("openapi.yaml");
            }
        }
    }

    // Create generated directory if it doesn't exist
    if let Some(output_parent) = output.parent() {
        fs::create_dir_all(output_parent)?;
    }

    println!("Transforming: {} → {}", input.display(), output.display());

    // Read and parse data.json
    let json_data = fs::read_to_string(&input)?;
    let catalog: Catalog = serde_json::from_str(&json_data)?;

    println!("Found {} datasets\n", catalog.dataset.len());

    // Use project root (parent of schemas/) as base for resolving relative schema file paths
    // If input is in schemas/, go up one level to get project root
    let base_dir = input.parent().and_then(|p| {
        if p.file_name() == Some(std::ffi::OsStr::new("schemas")) {
            p.parent()
        } else {
            Some(p)
        }
    });

    // Transform to OpenAPI
    let openapi_doc = transform_catalog(&catalog, base_dir)?;

    // Write to YAML
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
    println!("\nNext steps:");
    println!("  • Generate TypeScript: openapi-typescript openapi.yaml");
    println!("  • Generate Python: openapi-generator-cli generate -i openapi.yaml -g python");
    println!("  • Validate: swagger-cli validate openapi.yaml");

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

            let parsed = parser::parse_file_pattern(path)?;
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
