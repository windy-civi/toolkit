use from_chn_distributed_gov::prelude::*;
use futures::StreamExt;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Build configuration using the builder pattern
    let config = ConfigBuilder::new("tmp/git/windy-civi-pipelines")
        .sort_order_str("DESC")?
        .limit(10)
        .join_options_str("minimal_metadata,sponsors")?
        .build()?;

    // Create processor
    let processor = PipelineProcessor::new(config);

    // Process files reactively - files are streamed one at a time
    let mut stream = processor.process();

    // Consume the stream and print results
    while let Some(result) = stream.next().await {
        match result {
            Ok(entry) => {
                let json = serde_json::to_string(&entry)?;
                println!("{}", json);
            }
            Err(e) => {
                eprintln!("Error: {}", e);
            }
        }
    }

    Ok(())
}

