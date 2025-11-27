use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Project Open Data Catalog
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

/// Dataset with filesystem extensions
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

    // Filesystem extensions
    #[serde(rename = "x-filesystem-path")]
    pub filesystem_path: Option<String>,

    #[serde(rename = "x-path-parameters")]
    pub path_parameters: Option<Vec<PathParameter>>,

    #[serde(rename = "x-file-extensions")]
    pub file_extensions: Option<Vec<String>>,

    #[serde(rename = "x-schema-file")]
    pub schema_file: Option<String>,

    // Optional fields
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

/// OpenAPI 3.1 Document
#[derive(Debug, Serialize)]
pub struct OpenApiDocument {
    pub openapi: String,
    pub info: Info,
    pub paths: HashMap<String, PathItem>,
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
    pub responses: HashMap<String, Response>,
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
    pub content: Option<HashMap<String, MediaType>>,
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
    pub schemas: HashMap<String, Schema>,
}

#[derive(Debug, Serialize)]
pub struct Schema {
    #[serde(rename = "type")]
    pub type_: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub properties: Option<HashMap<String, Schema>>,
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

