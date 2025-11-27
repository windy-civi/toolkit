use regex::Regex;
use anyhow::Result;

#[derive(Debug)]
pub struct ParsedPattern {
    pub directory_path: String,
    pub filename_part: String,
    pub extension_part: String,
    pub dir_params: Vec<String>,
    pub file_params: Vec<String>,
    pub extension_params: Vec<String>,
}

/// Parse filesystem pattern with file extensions
/// Examples:
/// - "{bill_id}-{title}/logs/{timestamp}.voteevent.json"
/// - "data/{jurisdiction}/{session}/bills/{bill_id}.{format}"
pub fn parse_file_pattern(pattern: &str) -> Result<ParsedPattern> {
    // Find last slash to separate directory from filename
    let (dir_path, filename) = match pattern.rfind('/') {
        Some(pos) => (&pattern[..pos], &pattern[pos + 1..]),
        None => ("", pattern),
    };

    // Find first dot in filename to separate name from extension
    let (file_part, ext_part) = match filename.find('.') {
        Some(pos) => (&filename[..pos], &filename[pos + 1..]),
        None => (filename, ""),
    };

    // Extract parameters
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

/// Convert filesystem pattern to OpenAPI path
/// Removes file extensions and converts parameters
pub fn to_openapi_path(pattern: &str) -> Result<String> {
    let parsed = parse_file_pattern(pattern)?;

    // Build OpenAPI path without file extension
    let path = if parsed.directory_path.is_empty() {
        format!("/{}", parsed.filename_part)
    } else {
        format!("/{}/{}", parsed.directory_path, parsed.filename_part)
    };

    Ok(path)
}

/// Parse extension pattern to determine supported formats
/// Examples:
/// - "json" -> vec!["json"]
/// - "voteevent.json" -> vec!["voteevent.json"]
/// - "{format}" -> vec!["json", "xml", "csv"] (default options)
pub fn parse_extension(ext_part: &str) -> Vec<String> {
    if ext_part.contains('{') {
        // Variable extension - return default options
        vec!["json".to_string(), "xml".to_string(), "csv".to_string()]
    } else if !ext_part.is_empty() {
        // Fixed extension
        vec![ext_part.to_string()]
    } else {
        // No extension
        vec![]
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_complex_pattern() {
        let pattern = "{bill_id}-{title}/logs/{timestamp}.voteevent.json";
        let parsed = parse_file_pattern(pattern).unwrap();

        assert_eq!(parsed.directory_path, "{bill_id}-{title}/logs");
        assert_eq!(parsed.filename_part, "{timestamp}");
        assert_eq!(parsed.extension_part, "voteevent.json");
        assert_eq!(parsed.dir_params, vec!["bill_id", "title"]);
        assert_eq!(parsed.file_params, vec!["timestamp"]);
        assert!(parsed.extension_params.is_empty());
    }

    #[test]
    fn test_variable_extension() {
        let pattern = "data/{id}.{format}";
        let parsed = parse_file_pattern(pattern).unwrap();

        assert_eq!(parsed.extension_params, vec!["format"]);
    }

    #[test]
    fn test_openapi_path_conversion() {
        let pattern = "{bill_id}/logs/{timestamp}.json";
        let path = to_openapi_path(pattern).unwrap();

        assert_eq!(path, "/{bill_id}/logs/{timestamp}");
    }
}

