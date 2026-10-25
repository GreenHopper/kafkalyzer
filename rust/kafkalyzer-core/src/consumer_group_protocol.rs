use serde::{Deserialize, Serialize};

/// One topic-partition a consumer group member owns.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TopicPartition {
    pub topic: String,
    pub partition: i32,
}

fn read_i16(bytes: &[u8], cursor: &mut usize) -> Option<i16> {
    if *cursor + 2 > bytes.len() {
        return None;
    }
    let value = i16::from_be_bytes([bytes[*cursor], bytes[*cursor + 1]]);
    *cursor += 2;
    Some(value)
}

fn read_i32(bytes: &[u8], cursor: &mut usize) -> Option<i32> {
    if *cursor + 4 > bytes.len() {
        return None;
    }
    let value = i32::from_be_bytes([
        bytes[*cursor],
        bytes[*cursor + 1],
        bytes[*cursor + 2],
        bytes[*cursor + 3],
    ]);
    *cursor += 4;
    Some(value)
}

fn read_string(bytes: &[u8], cursor: &mut usize) -> Option<String> {
    let len = read_i16(bytes, cursor)?;
    if !(0..=10_000).contains(&len) || *cursor + len as usize > bytes.len() {
        return None;
    }
    let value = String::from_utf8(bytes[*cursor..*cursor + len as usize].to_vec()).ok()?;
    *cursor += len as usize;
    Some(value)
}

fn read_count(bytes: &[u8], cursor: &mut usize) -> Option<usize> {
    let count = read_i32(bytes, cursor)?;
    if !(0..=100_000).contains(&count) {
        return None;
    }
    Some(count as usize)
}

/// ConsumerProtocol subscription of one member: the topics it asked for.
pub fn parse_subscription(metadata: &[u8]) -> Option<Vec<String>> {
    let mut cursor = 0usize;
    read_i16(metadata, &mut cursor)?; // version
    let topic_count = read_count(metadata, &mut cursor)?;

    let mut topics = Vec::with_capacity(topic_count);
    for _ in 0..topic_count {
        topics.push(read_string(metadata, &mut cursor)?);
    }
    Some(topics)
}

/// ConsumerProtocol assignment of one member.
///
/// Returns `None` when the bytes cannot be decoded — an unknown assignor must
/// not be reported as "this member owns nothing".
pub fn parse_assignment(assignment: &[u8]) -> Option<Vec<TopicPartition>> {
    let mut cursor = 0usize;
    read_i16(assignment, &mut cursor)?; // version
    let topic_count = read_count(assignment, &mut cursor)?;

    let mut partitions = Vec::new();
    for _ in 0..topic_count {
        let topic = read_string(assignment, &mut cursor)?;
        let partition_count = read_count(assignment, &mut cursor)?;
        for _ in 0..partition_count {
            partitions.push(TopicPartition {
                topic: topic.clone(),
                partition: read_i32(assignment, &mut cursor)?,
            });
        }
    }

    // The cooperative assignor keeps the standard partition lists empty and
    // puts the real assignment into the JSON user data (KIP-429).
    if partitions.is_empty() {
        if let Some(user_data) = read_user_data(assignment, &mut cursor) {
            return parse_cooperative_user_data(&user_data);
        }
    }

    Some(partitions)
}

fn read_user_data(bytes: &[u8], cursor: &mut usize) -> Option<String> {
    let len = read_i32(bytes, cursor)?;
    if !(0..=1_000_000).contains(&len) || *cursor + len as usize > bytes.len() {
        return None;
    }
    String::from_utf8(bytes[*cursor..*cursor + len as usize].to_vec()).ok()
}

fn parse_cooperative_user_data(user_data: &str) -> Option<Vec<TopicPartition>> {
    let value: serde_json::Value = serde_json::from_str(user_data).ok()?;
    let assignment = value
        .get("assignment")
        .or_else(|| value.get("topicPartitions").map(|_| &value))?;
    let entries = assignment.get("topicPartitions")?.as_array()?;

    let mut partitions = Vec::new();
    for entry in entries {
        let topic = entry.get("topic")?.as_str()?.to_string();
        if let Some(numbers) = entry.get("partitions").and_then(|p| p.as_array()) {
            for number in numbers {
                partitions.push(TopicPartition {
                    topic: topic.clone(),
                    partition: number.as_i64()? as i32,
                });
            }
        }
    }
    Some(partitions)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn i16(value: i16) -> Vec<u8> {
        value.to_be_bytes().to_vec()
    }

    fn i32(value: i32) -> Vec<u8> {
        value.to_be_bytes().to_vec()
    }

    fn kafka_string(value: &str) -> Vec<u8> {
        let mut bytes = i16(value.len() as i16);
        bytes.extend_from_slice(value.as_bytes());
        bytes
    }

    #[test]
    fn subscription_lists_the_requested_topics() {
        let mut bytes = i16(0);
        bytes.extend(i32(1));
        bytes.extend(kafka_string("orders"));
        bytes.extend(i32(0)); // user data

        assert_eq!(parse_subscription(&bytes), Some(vec!["orders".to_string()]));
    }

    #[test]
    fn eager_assignment_lists_the_owned_partitions() {
        let mut bytes = i16(0);
        bytes.extend(i32(1)); // one topic
        bytes.extend(kafka_string("orders"));
        bytes.extend(i32(2)); // two partitions
        bytes.extend(i32(0));
        bytes.extend(i32(1));
        bytes.extend(i32(0)); // no user data

        assert_eq!(
            parse_assignment(&bytes),
            Some(vec![
                TopicPartition {
                    topic: "orders".to_string(),
                    partition: 0
                },
                TopicPartition {
                    topic: "orders".to_string(),
                    partition: 1
                },
            ])
        );
    }

    #[test]
    fn cooperative_assignment_is_read_from_the_user_data() {
        let json = r#"{"version":1,"assignment":{"topicPartitions":[{"topic":"orders","partitions":[2,3]}],"strategy":"cooperative-sticky"}}"#;
        let mut bytes = i16(0);
        bytes.extend(i32(1)); // one topic entry ...
        bytes.extend(kafka_string("orders"));
        bytes.extend(i32(0)); // ... with no partitions in the standard field
        bytes.extend(i32(json.len() as i32));
        bytes.extend(json.as_bytes());

        assert_eq!(
            parse_assignment(&bytes),
            Some(vec![
                TopicPartition {
                    topic: "orders".to_string(),
                    partition: 2
                },
                TopicPartition {
                    topic: "orders".to_string(),
                    partition: 3
                },
            ])
        );
    }

    #[test]
    fn cooperative_member_without_partitions_owns_nothing() {
        let json =
            r#"{"version":1,"assignment":{"topicPartitions":[],"strategy":"cooperative-sticky"}}"#;
        let mut bytes = i16(0);
        bytes.extend(i32(0));
        bytes.extend(i32(json.len() as i32));
        bytes.extend(json.as_bytes());

        assert_eq!(parse_assignment(&bytes), Some(vec![]));
    }

    #[test]
    fn undecodable_assignment_is_not_reported_as_empty() {
        assert_eq!(parse_assignment(&[0, 0, 0, 0, 0, 9]), None);
    }
}
