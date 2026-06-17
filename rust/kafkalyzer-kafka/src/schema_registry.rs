use anyhow::Result;
use kafkalyzer_core::kafka_types::ClusterProfile;
use tokio::runtime::Runtime;

pub fn fetch_subjects(profile: ClusterProfile) -> Result<Vec<String>> {
    let url = profile
        .schema_registry_url
        .clone()
        .ok_or_else(|| anyhow::anyhow!("No Schema Registry URL provided"))?;

    let rt = Runtime::new()?;

    let subjects = rt.block_on(async {
        let client = reqwest::Client::new();
        // TODO: Add Auth support if added to ClusterProfile
        let resp = client
            .get(format!("{}/subjects", url))
            .send()
            .await?
            .json::<Vec<String>>()
            .await?;
        Ok::<Vec<String>, anyhow::Error>(resp)
    })?;

    Ok(subjects)
}

pub fn fetch_schema(profile: ClusterProfile, subject: String) -> Result<String> {
    let url = profile
        .schema_registry_url
        .clone()
        .ok_or_else(|| anyhow::anyhow!("No Schema Registry URL provided"))?;

    let rt = Runtime::new()?;

    let schema_str = rt.block_on(async {
        let client = reqwest::Client::new();
        let resp = client
            .get(format!("{}/subjects/{}/versions/latest", url, subject))
            .send()
            .await?
            .json::<serde_json::Value>()
            .await?;

        // Extract "schema" field
        if let Some(schema) = resp.get("schema") {
            if let Some(s) = schema.as_str() {
                return Ok::<String, anyhow::Error>(s.to_string());
            }
        }
        Err(anyhow::anyhow!("Schema not found in response"))
    })?;

    Ok(schema_str)
}
