use anyhow::{Context, Result};
use serde_json::Value;
use std::collections::HashSet;
use std::fs;
use std::path::Path;
use crate::rss;

/// Load and parse govbot.yml configuration
pub fn load_config(config_path: &Path) -> Result<Value> {
    let contents = fs::read_to_string(config_path)
        .with_context(|| format!("Failed to read config file: {}", config_path.display()))?;
    serde_yaml::from_str(&contents)
        .with_context(|| format!("Failed to parse YAML: {}", config_path.display()))
}

/// Get repos list from config, handling 'all' special case
pub fn get_repos_from_config(config: &Value) -> Vec<String> {
    if let Some(repos) = config.get("repos") {
        if let Some(arr) = repos.as_array() {
            return arr
                .iter()
                .filter_map(|v| v.as_str().map(|s| s.to_string()))
                .collect();
        } else if let Some(s) = repos.as_str() {
            return vec![s.to_string()];
        }
    }
    vec!["all".to_string()]
}

/// Filter entries by tags
/// If tag_names is empty, includes all entries
/// If tags are specified but entry has no tags field, includes it (tags may not be generated yet)
/// If entry has tags, only includes if any tag matches
pub fn filter_by_tags(entry: &Value, tag_names: &[String]) -> bool {
    if tag_names.is_empty() {
        return true;
    }
    
    // If entry has tags, check if any match
    if let Some(tags) = entry.get("tags").and_then(|t| t.as_object()) {
        if tags.is_empty() {
            // Entry has tags object but it's empty - include it
            return true;
        }
        // Check if any specified tag matches
        for tag_name in tag_names {
            if tags.contains_key(tag_name) {
                return true;
            }
        }
        // Entry has tags but none match - exclude it
        return false;
    }
    
    // Entry has no tags field - include it
    // This allows entries without tags to pass through
    // (Tags may not be generated yet, or entry may legitimately have no tags)
    true
}

/// Deduplicate entries by GUID
pub fn deduplicate_entries(entries: Vec<Value>) -> Vec<Value> {
    let mut seen = HashSet::new();
    let mut result = Vec::new();
    
    for entry in entries {
        let guid = rss::extract_guid(&entry);
        if !seen.contains(&guid) {
            seen.insert(guid);
            result.push(entry);
        }
    }
    
    result
}

/// Sort entries by timestamp (newest first)
pub fn sort_by_timestamp(mut entries: Vec<Value>) -> Vec<Value> {
    entries.sort_by(|a, b| {
        let ts_a = a.get("timestamp").and_then(|t| t.as_str()).unwrap_or("");
        let ts_b = b.get("timestamp").and_then(|t| t.as_str()).unwrap_or("");
        ts_b.cmp(ts_a) // Reverse order (newest first)
    });
    entries
}

