use ort::inputs;
use ort::session::Session;
use ort::value::Value;
use std::collections::HashMap;
use std::path::Path;
use tokenizers::Tokenizer;

use ndarray::Array1;
use serde::Deserialize;

use crate::similarity::extract_text_from_json;

/// Tag definition provided by the creator
#[derive(Debug, Deserialize, Clone)]
pub struct TagDefinition {
    pub name: String,
    #[serde(default)]
    pub description: String,
    #[serde(default)]
    pub examples: Vec<String>,
    /// Minimum similarity score (0.0 - 1.0). Default to 0.3 if not provided.
    #[serde(default = "default_threshold")]
    pub threshold: f32,
}

fn default_threshold() -> f32 {
    0.3
}

#[derive(Debug, Deserialize)]
pub struct RawTag {
    #[serde(default)]
    pub description: String,
    #[serde(default)]
    pub examples: Vec<String>,
    #[serde(default = "default_threshold")]
    pub threshold: f32,
}

#[derive(Debug, Deserialize)]
pub struct RawTagConfig {
    pub tags: std::collections::HashMap<String, RawTag>,
}

pub fn load_tags_config<P: AsRef<Path>>(path: P) -> anyhow::Result<Vec<TagDefinition>> {
    let contents = std::fs::read_to_string(path)?;
    let raw: RawTagConfig = serde_yaml::from_str(&contents)
        .map_err(|e| anyhow::anyhow!("Failed to parse govbot.yml: {}", e))?;

    let mut tags = Vec::new();
    for (name, raw_tag) in raw.tags {
        tags.push(TagDefinition {
            name,
            description: raw_tag.description,
            examples: raw_tag.examples,
            threshold: raw_tag.threshold,
        });
    }
    Ok(tags)
}

/// Lightweight embedding service powered by ONNX Runtime
pub struct EmbeddingService {
    session: Session,
    tokenizer: Tokenizer,
}

impl EmbeddingService {
    pub fn new<P: AsRef<Path>>(model_path: P, tokenizer_path: P) -> anyhow::Result<Self> {
        let tokenizer = Tokenizer::from_file(tokenizer_path.as_ref())
            .map_err(|e| anyhow::anyhow!("Failed to load tokenizer: {}", e))?;

        let session = Session::builder()?.commit_from_file(model_path)?;

        Ok(Self { session, tokenizer })
    }

    /// Embed text using the configured model with mean pooling over last hidden state
    pub fn embed(&mut self, text: &str) -> anyhow::Result<Array1<f32>> {
        // Tokenize
        let encoding = self
            .tokenizer
            .encode(text, true)
            .map_err(|e| anyhow::anyhow!("Tokenizer encode failed: {}", e))?;

        let ids = encoding.get_ids();
        let mask = encoding.get_attention_mask();
        let type_ids = encoding.get_type_ids();

        let input_ids: Vec<i64> = ids.iter().map(|&x| x as i64).collect();
        let attention_mask_vec: Vec<i64> = mask.iter().map(|&x| x as i64).collect();
        let token_type_vec: Vec<i64> = type_ids.iter().map(|&x| x as i64).collect();

        let outputs = self.session.run(inputs![
            "input_ids" => Value::from_array((vec![1_i64, ids.len() as i64], input_ids))?,
            "attention_mask" => Value::from_array((vec![1_i64, mask.len() as i64], attention_mask_vec))?,
            "token_type_ids" => Value::from_array((vec![1_i64, type_ids.len() as i64], token_type_vec))?,
        ])?;

        // Use last_hidden_state and mean-pool
        let hidden = outputs["last_hidden_state"].try_extract_array::<f32>()?;

        // hidden shape: [batch, seq_len, hidden_dim]
        let shape = hidden.shape();
        if shape.len() != 3 {
            return Err(anyhow::anyhow!("Unexpected embedding shape {:?}", shape));
        }
        let seq_len = shape[1];
        let hidden_dim = shape[2];

        let mut pooled = vec![0f32; hidden_dim];
        for i in 0..seq_len {
            for h in 0..hidden_dim {
                pooled[h] += hidden[[0, i, h]];
            }
        }
        for h in 0..hidden_dim {
            pooled[h] /= seq_len as f32;
        }
        let pooled = Array1::from(pooled);

        Ok(pooled)
    }

    pub fn cosine_similarity(&self, a: &Array1<f32>, b: &Array1<f32>) -> f32 {
        let dot = a.dot(b);
        let norm_a = a.dot(a).sqrt();
        let norm_b = b.dot(b).sqrt();
        dot / (norm_a * norm_b).max(1e-9)
    }
}

/// Matcher that precomputes tag embeddings and scores logs against them
pub struct TagMatcher {
    embeddings: std::sync::Mutex<EmbeddingService>,
    tag_embeddings: HashMap<String, Array1<f32>>,
    tags: HashMap<String, TagDefinition>,
}

impl TagMatcher {
    pub fn from_files<P: AsRef<Path>>(
        model_path: P,
        tokenizer_path: P,
        tags_path: P,
    ) -> anyhow::Result<Self> {
        let mut embeddings = EmbeddingService::new(&model_path, &tokenizer_path)?;

        // Load tags YAML
        let tag_defs = load_tags_config(tags_path)?;

        // Precompute tag embeddings
        let mut tag_embeddings = HashMap::new();
        let mut tags_map = HashMap::new();

        for tag in tag_defs {
            // Combine description + examples for richer embedding
            let mut text = tag.description.clone();
            if !tag.examples.is_empty() {
                text.push_str(" Examples: ");
                text.push_str(&tag.examples.join(" | "));
            }
            let emb = embeddings.embed(&text)?;
            tag_embeddings.insert(tag.name.clone(), emb);
            tags_map.insert(tag.name.clone(), tag);
        }

        Ok(Self {
            embeddings: std::sync::Mutex::new(embeddings),
            tag_embeddings,
            tags: tags_map,
        })
    }

    /// Match a serde_json::Value log entry against tags, returning (tag, score)
    pub fn match_json_value(
        &self,
        value: &serde_json::Value,
    ) -> anyhow::Result<Vec<(String, f32)>> {
        let text = extract_text_from_json(value);
        let mut embeddings = self.embeddings.lock().unwrap();
        let log_embedding = embeddings.embed(&text)?;

        let mut results = Vec::new();
        for (name, tag_def) in &self.tags {
            if let Some(tag_emb) = self.tag_embeddings.get(name) {
                let score = embeddings.cosine_similarity(&log_embedding, tag_emb);
                if score >= tag_def.threshold {
                    results.push((name.clone(), score));
                }
            }
        }

        // Sort descending by score
        results.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));
        Ok(results)
    }

    /// Access tag definitions (name -> definition)
    pub fn tag_definitions(&self) -> &HashMap<String, TagDefinition> {
        &self.tags
    }
}
