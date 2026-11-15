import 'package:collection/collection.dart';
import 'package:kafkalyzer/src/features/topic/utils/dlq_topic_detector.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';

enum TopicFilterMode { substring, glob, regex }

enum TopicSortOrder { name, partitions, health }

class TopicListQuery {
  final String text;
  final TopicFilterMode mode;
  final bool showInternal;
  final bool showStream;
  final TopicSortOrder sort;
  final bool groupByPrefix;
  final Set<String> favourites;
  final Set<String> collapsedGroups;

  const TopicListQuery({
    this.text = '',
    this.mode = TopicFilterMode.substring,
    this.showInternal = false,
    this.showStream = false,
    this.sort = TopicSortOrder.name,
    this.groupByPrefix = false,
    this.favourites = const {},
    this.collapsedGroups = const {},
  });

  TopicListQuery copyWith({
    String? text,
    TopicFilterMode? mode,
    bool? showInternal,
    bool? showStream,
    TopicSortOrder? sort,
    bool? groupByPrefix,
    Set<String>? favourites,
    Set<String>? collapsedGroups,
  }) {
    return TopicListQuery(
      text: text ?? this.text,
      mode: mode ?? this.mode,
      showInternal: showInternal ?? this.showInternal,
      showStream: showStream ?? this.showStream,
      sort: sort ?? this.sort,
      groupByPrefix: groupByPrefix ?? this.groupByPrefix,
      favourites: favourites ?? this.favourites,
      collapsedGroups: collapsedGroups ?? this.collapsedGroups,
    );
  }

  static const _setEq = SetEquality<String>();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopicListQuery &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          mode == other.mode &&
          showInternal == other.showInternal &&
          showStream == other.showStream &&
          sort == other.sort &&
          groupByPrefix == other.groupByPrefix &&
          _setEq.equals(favourites, other.favourites) &&
          _setEq.equals(collapsedGroups, other.collapsedGroups);

  @override
  int get hashCode => Object.hash(
    text,
    mode,
    showInternal,
    showStream,
    sort,
    groupByPrefix,
    _setEq.hash(favourites),
    _setEq.hash(collapsedGroups),
  );
}

sealed class TopicListRow {
  const TopicListRow();
}

class FavouritesHeaderRow extends TopicListRow {
  final int count;
  const FavouritesHeaderRow(this.count);
}

class TopicGroupHeaderRow extends TopicListRow {
  final String prefix;
  final int count;
  final bool isCollapsed;
  const TopicGroupHeaderRow({
    required this.prefix,
    required this.count,
    required this.isCollapsed,
  });
}

class TopicItemRow extends TopicListRow {
  final String name;
  final TopicMetadata? topic;
  final bool isFavourite;
  final bool isMissingFavourite;

  const TopicItemRow({
    required this.name,
    this.topic,
    this.isFavourite = false,
    this.isMissingFavourite = false,
  });
}

class TopicListView {
  final List<TopicListRow> rows;
  final List<TopicMetadata> visibleTopics;
  final int hiddenByInternal;
  final int hiddenByStream;
  final int hiddenByText;
  final String? patternError;
  final RegExp? highlightPattern;
  final Map<String, List<String>> failureGroups;

  const TopicListView({
    required this.rows,
    required this.visibleTopics,
    required this.hiddenByInternal,
    required this.hiddenByStream,
    required this.hiddenByText,
    required this.patternError,
    required this.highlightPattern,
    required this.failureGroups,
  });

  int get totalHidden => hiddenByInternal + hiddenByStream + hiddenByText;
}

bool isInternalTopicName(String name) => name.startsWith('_');

bool isStreamTopicName(String name) {
  final lower = name.toLowerCase();
  return lower.endsWith('-changelog') || lower.endsWith('-repartition');
}

String? extractTopicPrefix(String name) {
  var start = 0;
  while (start < name.length && name.codeUnitAt(start) == 95) {
    start++;
  }
  for (var i = start; i < name.length; i++) {
    final c = name.codeUnitAt(i);
    // '.', '-', '_'
    if (c == 46 || c == 45 || c == 95) {
      if (i > start) {
        return name.substring(start, i);
      }
      return null;
    }
  }
  return null;
}

RegExp _compileGlob(String pattern) {
  final buf = StringBuffer('^');
  for (var i = 0; i < pattern.length; i++) {
    final ch = pattern[i];
    if (ch == '*') {
      buf.write('.*');
    } else if (ch == '?') {
      buf.write('.');
    } else {
      buf.write(RegExp.escape(ch));
    }
  }
  buf.write(r'$');
  return RegExp(buf.toString(), caseSensitive: false);
}

int _healthRank(TopicMetadata? t) {
  if (t == null) return 2;
  if (t.metadataError != null) return 0;
  final u = t.underReplicatedPartitions;
  final l = t.leaderlessPartitions;
  if (u == null || l == null) return 2;
  if (u + l > 0) return 1;
  return 3;
}

int _compareTopics(
  TopicMetadata? a,
  String aName,
  TopicMetadata? b,
  String bName,
  TopicSortOrder sort,
) {
  switch (sort) {
    case TopicSortOrder.name:
      return aName.compareTo(bName);
    case TopicSortOrder.partitions:
      final aKnown = a != null && a.metadataError == null;
      final bKnown = b != null && b.metadataError == null;
      if (aKnown != bKnown) {
        return aKnown ? -1 : 1;
      }
      if (aKnown && bKnown) {
        final cmp = b.partitionCount.compareTo(a.partitionCount);
        if (cmp != 0) return cmp;
      }
      return aName.compareTo(bName);
    case TopicSortOrder.health:
      final ra = _healthRank(a);
      final rb = _healthRank(b);
      if (ra != rb) return ra.compareTo(rb);
      if (ra == 1 && a != null && b != null) {
        final aAffected =
            (a.leaderlessPartitions ?? 0) + (a.underReplicatedPartitions ?? 0);
        final bAffected =
            (b.leaderlessPartitions ?? 0) + (b.underReplicatedPartitions ?? 0);
        final cmp = bAffected.compareTo(aAffected);
        if (cmp != 0) return cmp;
      }
      return aName.compareTo(bName);
  }
}

TopicListView buildTopicListView(List<TopicMetadata> all, TopicListQuery q) {
  RegExp? matcher;
  RegExp? highlightPattern;
  String? patternError;

  if (q.text.isNotEmpty) {
    switch (q.mode) {
      case TopicFilterMode.substring:
        final re = RegExp(RegExp.escape(q.text), caseSensitive: false);
        matcher = re;
        highlightPattern = re;
      case TopicFilterMode.glob:
        matcher = _compileGlob(q.text);
        highlightPattern = null;
      case TopicFilterMode.regex:
        try {
          final re = RegExp(q.text, caseSensitive: false);
          matcher = re;
          highlightPattern = re;
        } on FormatException catch (e) {
          patternError = e.message;
        }
    }
  }

  var hiddenByInternal = 0;
  var hiddenByStream = 0;
  var hiddenByText = 0;
  final visibleTopics = <TopicMetadata>[];
  Map<String, TopicMetadata>? byName;
  if (q.favourites.isNotEmpty) {
    byName = {for (final t in all) t.name: t};
  }

  for (final t in all) {
    if (!q.showInternal && isInternalTopicName(t.name)) {
      hiddenByInternal++;
      continue;
    }
    if (!q.showStream && isStreamTopicName(t.name)) {
      hiddenByStream++;
      continue;
    }
    if (matcher != null && !matcher.hasMatch(t.name)) {
      hiddenByText++;
      continue;
    }
    visibleTopics.add(t);
  }

  visibleTopics.sort((a, b) => _compareTopics(a, a.name, b, b.name, q.sort));

  final rows = <TopicListRow>[];

  if (q.favourites.isNotEmpty) {
    final favItems = <TopicItemRow>[];
    for (final fav in q.favourites) {
      if (matcher != null && !matcher.hasMatch(fav)) continue;
      final meta = byName![fav];
      favItems.add(
        TopicItemRow(
          name: fav,
          topic: meta,
          isFavourite: true,
          isMissingFavourite: meta == null,
        ),
      );
    }
    if (favItems.isNotEmpty) {
      favItems.sort(
        (a, b) => _compareTopics(a.topic, a.name, b.topic, b.name, q.sort),
      );
      rows.add(FavouritesHeaderRow(favItems.length));
      rows.addAll(favItems);
    }
  }

  if (!q.groupByPrefix) {
    for (final t in visibleTopics) {
      rows.add(
        TopicItemRow(
          name: t.name,
          topic: t,
          isFavourite: q.favourites.contains(t.name),
        ),
      );
    }
  } else {
    final buckets = <String, List<TopicMetadata>>{};
    final ungrouped = <TopicMetadata>[];

    for (final t in visibleTopics) {
      final prefix = extractTopicPrefix(t.name);
      if (prefix == null) {
        ungrouped.add(t);
      } else {
        (buckets[prefix] ??= []).add(t);
      }
    }

    final groupKeys = <String>[];
    for (final entry in buckets.entries) {
      if (entry.value.length >= 2) {
        groupKeys.add(entry.key);
      } else {
        ungrouped.addAll(entry.value);
      }
    }
    groupKeys.sort();
    ungrouped.sort((a, b) => _compareTopics(a, a.name, b, b.name, q.sort));

    for (final prefix in groupKeys) {
      final members = buckets[prefix]!;
      final isCollapsed = q.collapsedGroups.contains(prefix);
      rows.add(
        TopicGroupHeaderRow(
          prefix: prefix,
          count: members.length,
          isCollapsed: isCollapsed,
        ),
      );
      if (!isCollapsed) {
        for (final t in members) {
          rows.add(
            TopicItemRow(
              name: t.name,
              topic: t,
              isFavourite: q.favourites.contains(t.name),
            ),
          );
        }
      }
    }

    for (final t in ungrouped) {
      rows.add(
        TopicItemRow(
          name: t.name,
          topic: t,
          isFavourite: q.favourites.contains(t.name),
        ),
      );
    }
  }

  final failureGroups = DlqTopicDetector.groupFailureTopicsByBase([
    for (final t in visibleTopics) t.name,
  ]);

  return TopicListView(
    rows: rows,
    visibleTopics: visibleTopics,
    hiddenByInternal: hiddenByInternal,
    hiddenByStream: hiddenByStream,
    hiddenByText: hiddenByText,
    patternError: patternError,
    highlightPattern: highlightPattern,
    failureGroups: failureGroups,
  );
}
