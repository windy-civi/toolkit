use chrono::{DateTime, TimeZone, Utc};
use rss::{ChannelBuilder, ItemBuilder};
use serde_json::Value;
use std::collections::HashSet;

/// Parse timestamp string in format YYYYMMDDTHHMMSSZ to DateTime
pub fn parse_timestamp(timestamp_str: &str) -> Option<DateTime<Utc>> {
    // Format: 20250428T040000Z (Z indicates UTC)
    if timestamp_str.len() != 16 || !timestamp_str.ends_with('Z') {
        return None;
    }

    let date_part = &timestamp_str[0..8]; // YYYYMMDD
    let time_part = &timestamp_str[9..15]; // HHMMSS

    let year: i32 = date_part[0..4].parse().ok()?;
    let month: u32 = date_part[4..6].parse().ok()?;
    let day: u32 = date_part[6..8].parse().ok()?;

    let hour: u32 = time_part[0..2].parse().ok()?;
    let minute: u32 = time_part[2..4].parse().ok()?;
    let second: u32 = time_part[4..6].parse().ok()?;

    Utc.with_ymd_and_hms(year, month, day, hour, minute, second)
        .single()
}

/// Extract title from log entry
pub fn extract_title(entry: &Value) -> String {
    // Try bill title first
    if let Some(bill) = entry.get("bill").and_then(|b| b.as_object()) {
        if let Some(title) = bill.get("title").and_then(|t| t.as_str()) {
            let trimmed = title.trim();
            if !trimmed.is_empty() {
                return trimmed.to_string();
            }
        }
    }

    // Fall back to bill identifier
    let bill_id = entry
        .get("id")
        .or_else(|| entry.get("log").and_then(|l| l.get("bill_id")))
        .and_then(|id| id.as_str());

    if let Some(id) = bill_id {
        return format!("Bill Update: {}", id);
    }

    "Legislative Update".to_string()
}

/// Extract description from log entry
pub fn extract_description(entry: &Value) -> String {
    let mut parts = Vec::new();

    // Add action description if available
    if let Some(desc) = entry
        .get("log")
        .and_then(|l| l.get("action"))
        .and_then(|a| a.get("description"))
        .and_then(|d| d.as_str())
    {
        parts.push(desc.to_string());
    }

    // Add bill description if available
    if let Some(desc) = entry
        .get("bill")
        .and_then(|b| b.get("description"))
        .and_then(|d| d.as_str())
    {
        parts.push(desc.to_string());
    }

    // Add bill identifier
    if let Some(bill_id) = entry
        .get("id")
        .or_else(|| entry.get("log").and_then(|l| l.get("bill_id")))
        .and_then(|id| id.as_str())
    {
        parts.push(format!("Bill: {}", bill_id));
    }

    // Add session info
    if let Some(session) = entry
        .get("bill")
        .and_then(|b| b.get("legislative_session"))
        .and_then(|s| s.as_str())
    {
        parts.push(format!("Session: {}", session));
    }

    if parts.is_empty() {
        "Legislative update".to_string()
    } else {
        parts.join("\n\n")
    }
}

/// Extract or construct link from log entry
pub fn extract_link(entry: &Value, base_url: Option<&str>) -> Option<String> {
    // Try to get source URL from bill metadata
    if let Some(sources) = entry.get("sources").and_then(|s| s.as_object()) {
        if let Some(bill_source) = sources.get("bill").and_then(|s| s.as_str()) {
            if let Some(base) = base_url {
                let base_trimmed = base.trim_end_matches('/');
                return Some(format!("{}/{}", base_trimmed, bill_source));
            }
        }
    }

    // Try to get URL from bill sources
    if let Some(bill_sources) = entry
        .get("bill")
        .and_then(|b| b.get("sources"))
        .and_then(|s| s.as_array())
    {
        if let Some(first_source) = bill_sources.first().and_then(|s| s.as_object()) {
            if let Some(url) = first_source.get("url").and_then(|u| u.as_str()) {
                return Some(url.to_string());
            }
        }
    }

    None
}

/// Extract or generate a unique GUID for the entry
pub fn extract_guid(entry: &Value) -> String {
    // Use source log path as GUID if available
    if let Some(sources) = entry.get("sources").and_then(|s| s.as_object()) {
        if let Some(log_source) = sources.get("log").and_then(|s| s.as_str()) {
            return log_source.to_string();
        }
    }

    // Fall back to timestamp + bill_id
    let timestamp = entry
        .get("timestamp")
        .and_then(|t| t.as_str())
        .unwrap_or("");
    let bill_id = entry
        .get("id")
        .or_else(|| entry.get("log").and_then(|l| l.get("bill_id")))
        .and_then(|id| id.as_str())
        .unwrap_or("");

    format!("{}_{}", timestamp, bill_id)
}

/// Convert JSON Lines entries to RSS feed
pub fn json_to_rss(
    entries: Vec<Value>,
    title: &str,
    description: &str,
    link: &str,
    base_url: Option<&str>,
    language: &str,
    feed_tags: Option<&[String]>,
) -> String {
    let base_url = base_url.unwrap_or(link);

    let mut items = Vec::new();
    let mut seen_guids = HashSet::new();

    for entry in entries {
        let guid = extract_guid(&entry);

        // Deduplicate by GUID
        if seen_guids.contains(&guid) {
            continue;
        }
        seen_guids.insert(guid.clone());

        let mut item_builder = ItemBuilder::default();

        // Set title
        item_builder.title(extract_title(&entry));

        // Set description
        item_builder.description(extract_description(&entry));

        // Set link
        if let Some(item_link) = extract_link(&entry, Some(base_url)) {
            item_builder.link(item_link);
        }

        // Set publication date
        if let Some(timestamp) = entry.get("timestamp").and_then(|t| t.as_str()) {
            if let Some(pub_date) = parse_timestamp(timestamp) {
                item_builder.pub_date(pub_date.to_rfc2822());
            }
        }

        // Set GUID
        item_builder.guid(rss::Guid {
            value: guid,
            permalink: false,
        });

        // Add categories from feed tags (tags used to filter this feed)
        // These are always added since we know they're relevant to this feed
        if let Some(feed_tags) = feed_tags {
            for tag_name in feed_tags {
                item_builder.category(rss::Category {
                    name: tag_name.clone(),
                    domain: None,
                });
            }
        }

        // Also add categories from entry tags if available (in case there are additional tags)
        if let Some(tags) = entry.get("tags").and_then(|t| t.as_object()) {
            for tag_name in tags.keys() {
                // Only add if not already added from feed_tags (avoid duplicates)
                let already_added = feed_tags.map(|ft| ft.contains(tag_name)).unwrap_or(false);
                if !already_added {
                    item_builder.category(rss::Category {
                        name: tag_name.clone(),
                        domain: None,
                    });
                }
            }
        }

        items.push(item_builder.build());
    }

    // Build channel
    let channel = ChannelBuilder::default()
        .title(title)
        .link(link)
        .description(description)
        .language(Some(language.to_string()))
        .last_build_date(Some(Utc::now().to_rfc2822()))
        .items(items)
        .build();

    channel.to_string()
}
