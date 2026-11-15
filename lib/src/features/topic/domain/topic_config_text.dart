import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/topic_config.dart';

String topicConfigSourceLabel(TopicConfigSource source, AppLocalizations l10n) {
  return switch (source) {
    TopicConfigSource.dynamicTopic => l10n.topicConfigSourceDynamicTopic,
    TopicConfigSource.dynamicBroker => l10n.topicConfigSourceDynamicBroker,
    TopicConfigSource.dynamicDefaultBroker =>
      l10n.topicConfigSourceDynamicDefaultBroker,
    TopicConfigSource.staticBroker => l10n.topicConfigSourceStaticBroker,
    TopicConfigSource.default_ => l10n.topicConfigSourceDefault,
    TopicConfigSource.unknown => l10n.topicConfigSourceUnknown,
  };
}

String topicConfigStatusLabel(
  TopicConfigDiffStatus status,
  AppLocalizations l10n,
) {
  return switch (status) {
    TopicConfigDiffStatus.equal => l10n.topicConfigStatusEqual,
    TopicConfigDiffStatus.different => l10n.topicConfigStatusDifferent,
    TopicConfigDiffStatus.onlyLeft => l10n.topicConfigStatusOnlyLeft,
    TopicConfigDiffStatus.onlyRight => l10n.topicConfigStatusOnlyRight,
    TopicConfigDiffStatus.notComparable => l10n.topicConfigStatusNotComparable,
    TopicConfigDiffStatus.unknown => l10n.topicConfigStatusUnknown,
  };
}

String topicConfigValueLabel(
  TopicConfigEntry? entry,
  AppLocalizations l10n, {
  bool sideAvailable = true,
}) {
  if (entry == null) {
    return sideAvailable
        ? l10n.topicConfigPlaceholderNoValue
        : l10n.topicConfigPlaceholderUnknown;
  }
  if (entry.isSensitive) {
    return l10n.topicConfigPlaceholderSensitive;
  }
  return entry.value ?? l10n.topicConfigPlaceholderNoValue;
}

String topicConfigUnavailableReason(
  TopicConfigSnapshot snapshot,
  AppLocalizations l10n,
) {
  return switch (snapshot.availability) {
    TopicConfigAvailability.available => '',
    TopicConfigAvailability.notAuthorized =>
      l10n.topicConfigUnavailableNotAuthorized,
    TopicConfigAvailability.topicNotFound =>
      l10n.topicConfigUnavailableNotFound,
    TopicConfigAvailability.failed => l10n.topicConfigUnavailableFailed(
      snapshot.errorMessage ?? l10n.topicConfigPlaceholderUnknown,
    ),
  };
}

/// Formats visible configuration entries (single mode) as plain tab-separated text.
String formatSingleTopicConfigText({
  required String profileName,
  required String topicName,
  required TopicConfigSnapshot snapshot,
  required List<TopicConfigEntry> visibleEntries,
  required AppLocalizations l10n,
}) {
  final lines = <String>['$profileName / $topicName'];
  if (snapshot.availability != TopicConfigAvailability.available) {
    lines.add(topicConfigUnavailableReason(snapshot, l10n));
    return lines.join('\n');
  }

  lines.add(
    [
      l10n.topicConfigColumnName,
      l10n.topicConfigColumnValue,
      l10n.topicConfigColumnSource,
      l10n.topicConfigColumnDefault,
    ].join('\t'),
  );
  for (final e in visibleEntries) {
    lines.add(
      [
        e.name,
        topicConfigValueLabel(e, l10n),
        topicConfigSourceLabel(e.source, l10n),
        e.isDefault ? l10n.topicConfigDefaultYes : l10n.topicConfigDefaultNo,
      ].join('\t'),
    );
  }
  return lines.join('\n');
}

/// Formats visible comparison rows as plain tab-separated text, including
/// profile/topic headers and unreadable side notices.
String formatTopicConfigDiffText({
  required String leftProfileName,
  required String leftTopicName,
  required TopicConfigSnapshot? leftSnapshot,
  required String rightProfileName,
  required String rightTopicName,
  required TopicConfigSnapshot? rightSnapshot,
  required int? differenceCount,
  required List<TopicConfigDiffRow> visibleRows,
  required AppLocalizations l10n,
}) {
  final leftAvailable =
      leftSnapshot?.availability == TopicConfigAvailability.available;
  final rightAvailable =
      rightSnapshot?.availability == TopicConfigAvailability.available;

  final lines = <String>[
    '$leftProfileName / $leftTopicName  <>  $rightProfileName / $rightTopicName',
    differenceCount != null
        ? l10n.topicConfigDifferencesCount(differenceCount)
        : l10n.topicConfigDifferencesUnknown,
  ];
  if (leftSnapshot != null && !leftAvailable) {
    lines.add(
      '$leftProfileName / $leftTopicName: ${topicConfigUnavailableReason(leftSnapshot, l10n)}',
    );
  }
  if (rightSnapshot != null && !rightAvailable) {
    lines.add(
      '$rightProfileName / $rightTopicName: ${topicConfigUnavailableReason(rightSnapshot, l10n)}',
    );
  }
  if (!leftAvailable && !rightAvailable) {
    return lines.join('\n');
  }

  lines.add(
    [
      l10n.topicConfigColumnName,
      l10n.topicConfigColumnLeftValue,
      l10n.topicConfigColumnLeftSource,
      l10n.topicConfigColumnRightValue,
      l10n.topicConfigColumnRightSource,
      l10n.topicConfigColumnStatus,
    ].join('\t'),
  );

  for (final row in visibleRows) {
    final leftVal = row.left != null
        ? topicConfigValueLabel(row.left, l10n)
        : (leftAvailable
              ? l10n.topicConfigPlaceholderNoValue
              : l10n.topicConfigPlaceholderUnknown);
    final leftSrc = row.left != null
        ? topicConfigSourceLabel(row.left!.source, l10n)
        : (leftAvailable
              ? l10n.topicConfigPlaceholderNoValue
              : l10n.topicConfigPlaceholderUnknown);
    final rightVal = row.right != null
        ? topicConfigValueLabel(row.right, l10n)
        : (rightAvailable
              ? l10n.topicConfigPlaceholderNoValue
              : l10n.topicConfigPlaceholderUnknown);
    final rightSrc = row.right != null
        ? topicConfigSourceLabel(row.right!.source, l10n)
        : (rightAvailable
              ? l10n.topicConfigPlaceholderNoValue
              : l10n.topicConfigPlaceholderUnknown);
    lines.add(
      [
        row.name,
        leftVal,
        leftSrc,
        rightVal,
        rightSrc,
        topicConfigStatusLabel(row.status, l10n),
      ].join('\t'),
    );
  }
  return lines.join('\n');
}
