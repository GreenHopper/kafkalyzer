## 1. Controller and Widget Enhancements

- [x] 1.1 Add `streamTopicWithDefaults(TopicMetadata topic, [ClusterProfile? profile])` method to `ActiveConnectionController` in `lib/src/features/cluster/presentation/controllers/active_connection_controller.dart` to open/focus the topic tab and immediately call `startStreaming` with default parameters (latest 200 messages)
- [x] 1.2 Update `TopicListItem` in `lib/src/features/topic/presentation/widgets/topic_list_item.dart` to accept an `onDoubleTap` callback and trigger it on double-tap
- [x] 1.3 Wire `onDoubleTap` in `ExplorerView` (`lib/src/features/explorer/presentation/explorer_view.dart`) to invoke `streamTopicWithDefaults` on the active cluster

## 2. Verification & Testing

- [x] 2.1 Add unit/widget tests for `streamTopicWithDefaults` in `ActiveConnectionController` and `TopicListItem` double-tap gesture support and verify with `flutter test`
- [x] 2.2 Run static analysis (`flutter analyze` or `dart analyze`) to ensure zero lint errors and conformance to code formatting standards
