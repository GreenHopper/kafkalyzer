# Spike: Listing Committed Offsets of a Member-Less Consumer Group (D1)

## 1.1 Reproducible Broker Fixture (`localhost:9094`)

Started `kafka` via `docker compose up -d kafka` (`sift_kafka`, Confluent Platform `confluentinc/cp-kafka:7.6.0`, external listener `localhost:9094`, internal listener `sift_kafka:29092`):

```bash
docker exec sift_kafka kafka-topics --bootstrap-server sift_kafka:29092 \
  --create --topic lag-spike --replication-factor 1 --partitions 3

seq 1 150 | sed 's/^/msg-/' | docker exec -i sift_kafka kafka-console-producer \
  --bootstrap-server sift_kafka:29092 --topic lag-spike

docker exec sift_kafka kafka-console-consumer --bootstrap-server sift_kafka:29092 \
  --topic lag-spike --group lag-spike-g --from-beginning --max-messages 100 > /dev/null

docker exec sift_kafka kafka-consumer-groups --bootstrap-server sift_kafka:29092 \
  --delete-offsets --group lag-spike-g --topic lag-spike:1

docker exec sift_kafka kafka-consumer-groups --bootstrap-server sift_kafka:29092 \
  --describe --group lag-spike-g
```

Observed output:

```text
Consumer group 'lag-spike-g' has no active members.

GROUP           TOPIC           PARTITION  CURRENT-OFFSET  LOG-END-OFFSET  LAG             CONSUMER-ID     HOST            CLIENT-ID
lag-spike-g     lag-spike       0          0               0               0               -               -               -
lag-spike-g     lag-spike       2          100             150             50              -               -               -
```

`lag-spike` has 3 partitions (`0`, `1`, `2`), `lag-spike-g` is in state `Empty` (`0` members), partition `0` has committed offset `0` (log end `0`), partition `1` has no commit, and partition `2` has committed offset `100` (log end `150`, lag `50`).

## 1.2 Candidate A: `rd_kafka_ListConsumerGroupOffsets` (`rdkafka-sys` 4.7.0 / librdkafka 2.3.0)

- Calling `rd_kafka_ListConsumerGroupOffsets_new(c_group, ptr::null())` via `AdminClient::inner().native_ptr()` returned all committed partitions for `lag-spike-g` in one `OffsetFetch` request (`~4.0 ms`):
  - `lag-spike[0] offset=0 err=RD_KAFKA_RESP_ERR_NO_ERROR`
  - `lag-spike[2] offset=100 err=RD_KAFKA_RESP_ERR_NO_ERROR`
- Nonexistent or commit-less group (`nonexistent-spike-g`): `groups_cnt=1`, `group_result_error` is `NULL`, `partitions_cnt=0` (`~0.8 ms`). Existence/group errors (`GROUP_AUTHORIZATION_FAILED`, unknown group) are distinguished via `fetch_group_list` / `rd_kafka_group_result_error`.
- Per-partition authorization/coordinator errors are returned in `rd_kafka_topic_partition_t.err`.
- Required `unsafe` surface: small, self-contained wrapper around `rd_kafka_queue_new`, `rd_kafka_ListConsumerGroupOffsets_new`, `rd_kafka_AdminOptions_new(LISTCONSUMERGROUPOFFSETS)`, `rd_kafka_AdminOptions_set_request_timeout`, `rd_kafka_ListConsumerGroupOffsets`, `rd_kafka_queue_poll`, `rd_kafka_event_ListConsumerGroupOffsets_result`, `rd_kafka_ListConsumerGroupOffsets_result_groups`, `rd_kafka_group_result_error`, `rd_kafka_group_result_partitions`, and RAII `Drop` cleanup (`*_destroy`).

## 1.3 Candidate B: `BaseConsumer::committed_offsets` (no subscribe/assign)

- `BaseConsumer` configured with `group.id=lag-spike-g`, `enable.auto.commit=false`, `enable.auto.offset.store=false`, querying all 3 non-internal partitions:
  - `lag-spike[0] offset=Offset(0) err=Ok(())`
  - `lag-spike[1] offset=Invalid err=Ok(())`
  - `lag-spike[2] offset=Offset(100) err=Ok(())`
  - Latency for 3 partitions: `~1.4 ms`.
- Scaling to 10,000 partitions requires serializing and querying all 10,000 `TopicPartition` entries in every group's `OffsetFetch` request (roughly proportional to cluster partition count, e.g. ~50–150 ms+ per group and large payloads), whereas Candidate A is `O(committed partitions of that group)` and needs no cluster-wide partition scan or partition cap.

## 1.4 Read-Only Verification

- Ran the prototype 5 consecutive times against `lag-spike-g`:
  - `kafka-consumer-groups --describe --members --group lag-spike-g` reported `Consumer group 'lag-spike-g' has no active members.`
  - `kafka-consumer-groups --describe --group lag-spike-g` confirmed committed offsets (`0` on partition 0, `100` on partition 2, none on partition 1) remained unchanged.
- Ran against a live `kafka-console-consumer` group (`lag-spike-live-g`, 3 partitions): `CONSUMER-ID` (`console-consumer-5d110d20-45cb-457c-a30e-38619322cf7e`) and partition ownership remained unchanged with no rebalance.

## 1.5 Decision

- **Chosen approach:** **Candidate A (`rd_kafka_ListConsumerGroupOffsets` with `partitions = NULL`)** wrapped in RAII guards in `kafkalyzer-kafka`.
- **Chunk size (Dart UI batched queries):** `20` groups per `fetchConsumerGroupLags` call (bounded per-call latency while sharing cluster metadata and watermark caches).
- **Candidate-B partition cap:** Not applicable (Candidate A selected; no cluster-wide partition scan).

## 3.4 Shared Implementation Verification (`integration_lag_spike_g_empty_group_has_accurate_lags`)

- Ran `fetch_consumer_group_lag(profile, "lag-spike-g")` against `localhost:9094`:
  - `state == "Empty"`, `lag_error == None`, `ownership_known == false`
  - `lag-spike` lists all 3 partitions:
    - partition `0`: `Known`, `lag = 0` (`current_offset = 0`, `log_end_offset = 0`)
    - partition `1`: `NoCommit` (`current_offset = -1`, `log_end_offset = 0`)
    - partition `2`: `Known`, `lag = 50` (`current_offset = 100`, `log_end_offset = 150`)
  - Also caught and worked around `rdkafka` 0.36.2 calling `slice::from_raw_parts(null, 0)` in `GroupInfo::members()` when `member_cnt == 0` (`safe_collect_members`).
