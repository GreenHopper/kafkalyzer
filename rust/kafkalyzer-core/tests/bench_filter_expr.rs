use kafkalyzer_core::filter_expr::{compile_str, MessageView};
use serde_json::Value;
use std::cell::OnceCell;
use std::collections::HashMap;
use std::time::Instant;

fn make_payload(target_bytes: usize, status: &str) -> Vec<u8> {
    let mut s = format!(r#"{{"order":{{"status":"{status}","amount":150}},"pad":""#);
    while s.len() + 2 < target_bytes {
        s.push('x');
    }
    s.push_str(r#""}"#);
    s.into_bytes()
}

struct BenchMsg<'a> {
    bytes: &'a [u8],
    parsed: OnceCell<Option<Value>>,
}

impl<'a> BenchMsg<'a> {
    fn new(bytes: &'a [u8]) -> Self {
        Self {
            bytes,
            parsed: OnceCell::new(),
        }
    }
}

impl<'a> MessageView for BenchMsg<'a> {
    fn partition(&self) -> i32 {
        0
    }
    fn offset(&self) -> i64 {
        1
    }
    fn timestamp(&self) -> Option<i64> {
        Some(1_700_000_000_000)
    }
    fn header(&self, _name: &str) -> Option<&[u8]> {
        None
    }
    fn key_bytes(&self) -> Option<&[u8]> {
        None
    }
    fn key_json(&self) -> Option<&Value> {
        None
    }
    fn key_text(&self) -> Option<&str> {
        None
    }
    fn value_json(&self) -> Option<&Value> {
        self.parsed
            .get_or_init(|| serde_json::from_slice(self.bytes).ok())
            .as_ref()
    }
    fn value_text(&self) -> Option<&str> {
        None
    }
}

#[test]
#[ignore]
fn bench_filter_expr_vs_legacy_contains() {
    let count = 100_000usize;
    let compiled = compile_str(r#"value.order.status = "FAILED""#, &HashMap::new()).unwrap();

    for (label, size) in [("1KB", 1024usize), ("50KB", 50 * 1024usize)] {
        let match_bytes = make_payload(size, "FAILED");
        let miss_bytes = make_payload(size, "OK");

        // 1. Legacy-style: parse -> to_string_pretty -> substring contains
        let t0 = Instant::now();
        let mut legacy_hits = 0usize;
        for i in 0..count {
            let bytes = if i % 10 == 0 {
                &match_bytes
            } else {
                &miss_bytes
            };
            let val: Value = serde_json::from_slice(bytes).unwrap();
            let pretty = serde_json::to_string_pretty(&val).unwrap();
            if pretty.contains("FAILED") {
                legacy_hits += 1;
            }
        }
        let legacy_secs = t0.elapsed().as_secs_f64();

        // 2. Real filter_expr evaluator over MessageView
        let t1 = Instant::now();
        let mut expr_hits = 0usize;
        for i in 0..count {
            let bytes = if i % 10 == 0 {
                &match_bytes
            } else {
                &miss_bytes
            };
            let msg = BenchMsg::new(bytes);
            if compiled.evaluate(&msg) {
                expr_hits += 1;
            }
        }
        let expr_secs = t1.elapsed().as_secs_f64();

        assert_eq!(legacy_hits, expr_hits);
        println!(
            "{label} ({count} msgs): legacy_pretty_contains={:.0} msg/s ({:.3}s), filter_expr={:.0} msg/s ({:.3}s)",
            count as f64 / legacy_secs,
            legacy_secs,
            count as f64 / expr_secs,
            expr_secs,
        );
    }
}
