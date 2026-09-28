# UX- & Architektur-Konzept: Flexible Visualisierung komplexer Kafka-Messages in Flutter

Anhand deiner Screenshots wird die Kernproblematik deutlich:
1. **Hohe Schachtelungstiefe:** Strukturen wie `leistungen[x].sortOrders[y]` erzeugen im Tree-View enorme vertikale Listen, bei denen der Kontext (welche Leistung gehört zu welchem Kennzeichen?) schnell verloren geht.
2. **Tabellen-Unschärfe:** In der Listen-/Tabellenansicht wird die Payload als roher JSON-String abgeschnitten dargestellt. Ein gezielter Quervergleich zwischen 10 Treffern erfordert das Öffnen von 10 Modals.
3. **Suchtreffer-Kontext:** Bei der Suche nach einer ID (wie im modalen Screenshot zu sehen) muss man manuell tief navigieren, obwohl eigentlich nur dieser Treffer plus 1–2 Nachbar-Knoten relevant sind.
4. **Ansichten-Fragmentierung:** Die Anwendung wechselt zwischen vier getrennten Modi (Timeline-Rail, Flache Tabelle, Diff-Ansicht, Vollbild-Modal). Das zwingt den Nutzer zum ständigen mentalen Kontextwechsel.

---

## 1. Kernkonzepte für die UX-Verbesserung

### A. Field Projection & Presets ("Spalten- & Feldfilter")
Statt dem Nutzer das gesamte JSON aufzuzwingen, definierst du **View Presets** (gespeichert pro Topic oder pro Skript):
- **User-definierte Projektionen:** Der Nutzer kann festlegen, welche Felder in der Übersicht und im Detail primär interessieren (z. B. `kennzeichen`, `leistungen[].leistungId`, `sortOrders[].value`).
- **One-Click "Add to Table":** Klickt der Nutzer im Detail-Tree auf einen Key (z. B. Rechtsklick auf `transportId`), gibt es die Option: *"Als Spalte zur Übersichtstabelle hinzufügen"*.

### B. Smart Collapse & Match-Focus im Tree-View
Wenn der User nach einem Suchbegriff filtert (z. B. `a1a316b3-a493-...`):
- **Isolationsmodus ("Prune Unrelated"):** Alle JSON-Äste, die keinen Treffer enthalten, werden automatisch ausgeblendet oder eingeklappt.
- **Breadcrumb-Pfad:** Oberhalb des Matches wird ein Breadcrumb angezeigt:
  `Root > leistungen [14] > sortOrders [4] > transportId`.

### C. Adaptive "Array-to-Table" Visualisierung
Arrays von gleichförmigen Objekten (z. B. `sortOrders` oder `leistungen`) sind im Tree-Format unübersichtlich.
- **Flache Tabellendarstellung für Listen:** Sobald eine Liste aus gleichartigen Maps besteht, wird diese nicht als Baum (`[0] -> key: val`, `[1] -> key: val`), sondern als kompakte **Sub-Tabelle** dargestellt.

### D. Master-Detail Split-Screen statt Modal Dialog
Ein modaler Dialog (Screenshot 1) blockiert den Workflow. 
- Ein **Side-Sheet (Split-View)** rechts erlaubt es, mit Tastatur (Pfeiltasten hoch/runter) durch die Trefferliste zu steppen, während sich rechts sofort die projizierten Details aktualisieren.

---

## 2. Progressive Disclosure: "Smart Badges" für Verbundobjekte

### 2.1 Bewertung der Idee: Verbundobjekte als Badges komprimieren
Die Idee, semantisch zusammengehörige Objektstrukturen (wie Adressen, Geo-Positionen, Zeitfenster oder Personenangaben) auf ein einzelnes **Inline-Badge** zu reduzieren und Details per Hover/Klick nachzuladen, ist **exzellent**. 

Im UX-Design nennt man dies **Progressive Disclosure** (schrittweise Informationsenthüllung):
- **Visuelle Entlastung:** Ein Adressobjekt mit 6 Schlüsseln (`strasse`, `hausnummer`, `plz`, `ort`, `land`, `zusatz`) belegt im Tree normalerweise 6 Zeilen. Als Badge benötigt es **eine Zeile** oder **ein einzelnes Inline-Element** in einer Tabellenzelle.
- **Kognitive Lesbarkeit:** Ein Mensch liest `📍 Musterstraße 12, 1010 Wien` in Millisekunden, während das Gehirn beim Parsen von `{ "strasse": "...", "plz": "..." }` aktiv JSON-Syntax filtern muss.

### 2.2 Wichtige UI/UX-Fallstricke & wie du sie vermeidest

1. **Der Tooltip-Fluch (Das Copy-Paste-Problem):**
   - Standard-Tooltips (`Tooltip` in Flutter) verschwinden sofort, wenn der Mauszeiger die Quelle verlässt.
   - **Problem:** Kafka-Analysten wollen oft IDs, PLZ oder Straßennamen aus dem Pop-up kopieren.
   - **Lösung:** Verwende kein rein flüchtiges Tooltip, sondern ein **interaktives Popover / Flyout** (via `OverlayPortal` oder `TapRegion`), das geöffnet bleibt, während die Maus sich im Popover befindet, oder das bei Klick "festpinnt".

2. **Schema-Agnostik (Wie erkennt das System eine Adresse?):**
   - Da Kafka-Topics unterschiedliche Payloads haben, solltest du mit einer **Regel- und Heuristik-Engine** arbeiten:
     - **Regel 1 (Schema-Matching):** Enthält das Objekt Keys wie `['ort', 'plz']` oder `['street', 'zip', 'city']`? $\rightarrow$ Auto-Badge: Adresse.
     - **Regel 2 (Geo-Koordinaten):** Enthält das Objekt `lat` und `lon` / `lng`? $\rightarrow$ Auto-Badge: `🌐 48.2082, 16.3738`.
     - **Regel 3 (Zeitfenster):** Enthält das Objekt `from`/`to` oder `startDate`/`endDate`? $\rightarrow$ Auto-Badge: `⏱ 24.09 08:00 → 26.08 14:00`.
     - **Regel 4 (Benutzerdefiniert):** Im UI kann der Nutzer definieren: *„Behandle Knoten `xyz` als Badge mit Template `${strasse}, ${ort}`“*.

---

## 3. Technische Umsetzung in Flutter: Interaktive Smart Badges

### 3.1 Heuristik & Formatter-Engine (Entity Formatter)

```dart
/// Definiert die Repräsentation eines komprimierten Objekts
class FormattedBadgeData {
  final IconData icon;
  final String label;
  final Color? color;

  FormattedBadgeData({required this.icon, required this.label, this.color});
}

/// Erkennt automatisch bekannte Verbundstrukturen
class EntityFormatterRegistry {
  static FormattedBadgeData? tryFormat(Map<String, dynamic> map) {
    final keys = map.keys.map((k) => k.toLowerCase()).toSet();

    // 1. Adress-Heuristik
    if (keys.contains('ort') || keys.contains('city') || keys.contains('plz')) {
      final street = map['strasse'] ?? map['street'] ?? '';
      final zip = map['plz'] ?? map['zip'] ?? '';
      final city = map['ort'] ?? map['city'] ?? '';
      final label = [street, [zip, city].where((s) => s.toString().isNotEmpty).join(' ')]
          .where((s) => s.toString().trim().isNotEmpty)
          .join(', ');
      
      return FormattedBadgeData(
        icon: Icons.location_on_outlined,
        label: label.isEmpty ? 'Adresse' : label,
        color: Colors.blueAccent,
      );
    }

    // 2. Zeitfenster / Periode
    if ((keys.contains('startdate') || keys.contains('validfrom')) &&
        (keys.contains('enddate') || keys.contains('validto'))) {
      final start = (map['startDate'] ?? map['validFrom'] ?? '').toString().split('T').first;
      final end = (map['endDate'] ?? map['validTo'] ?? '').toString().split('T').first;
      return FormattedBadgeData(
        icon: Icons.date_range_outlined,
        label: '$start → $end',
        color: Colors.orangeAccent,
      );
    }

    // 3. Geokoordinaten
    if ((keys.contains('lat') || keys.contains('latitude')) &&
        (keys.contains('lon') || keys.contains('lng') || keys.contains('longitude'))) {
      final lat = map['lat'] ?? map['latitude'];
      final lon = map['lon'] ?? map['lng'] ?? map['longitude'];
      return FormattedBadgeData(
        icon: Icons.pin_drop_outlined,
        label: '$lat, $lon',
        color: Colors.green,
      );
    }

    return null; // Kein bekanntes Muster -> Regulär als Map rendern
  }
}
```

---

### 3.2 Das Smart-Badge Widget mit interaktivem Kopier-Popover

Dieses Widget nutzt `OverlayPortal`, um sicherzustellen, dass das Pop-up weder abgeschnitten wird noch sofort verschwindet, wenn der Nutzer Text markieren oder kopieren möchte.

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SmartCompositeBadge extends StatefulWidget {
  final String keyName;
  final Map<String, dynamic> data;
  final FormattedBadgeData badgeInfo;

  const SmartCompositeBadge({
    super.key,
    required this.keyName,
    required this.data,
    required this.badgeInfo,
  });

  @override
  State<SmartCompositeBadge> createState() => _SmartCompositeBadgeState();
}

class _SmartCompositeBadgeState extends State<SmartCompositeBadge> {
  final _overlayController = OverlayPortalController();
  final _link = LayerLink();
  bool _isPinnedByClick = false;

  void _show() {
    if (!_overlayController.isShowing) {
      _overlayController.show();
    }
  }

  void _hide() {
    if (!_isPinnedByClick && _overlayController.isShowing) {
      _overlayController.hide();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badgeColor = widget.badgeInfo.color ?? theme.colorScheme.primary;

    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _overlayController,
        overlayChildBuilder: (context) => _buildPopover(context, badgeColor),
        child: MouseRegion(
          onEnter: (_) => _show(),
          onExit: (_) => _hide(),
          child: InkWell(
            onTap: () {
              setState(() {
                _isPinnedByClick = !_isPinnedByClick;
                if (_isPinnedByClick) _show();
                else _hide();
              });
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                border: Border.all(
                  color: _isPinnedByClick ? badgeColor : badgeColor.withValues(alpha: 0.4),
                  width: _isPinnedByClick ? 1.5 : 1.0,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.badgeInfo.icon, size: 14, color: badgeColor),
                  const SizedBox(width: 5),
                  Text(
                    '${widget.keyName}: ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: badgeColor.withValues(alpha: 0.8),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: Text(
                      widget.badgeInfo.label,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isPinnedByClick ? Icons.lock : Icons.unfold_more,
                    size: 11,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopover(BuildContext context, Color badgeColor) {
    return Positioned(
      width: 320,
      child: CompositedTransformFollower(
        link: _link,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, 4),
        child: MouseRegion(
          onEnter: (_) => _show(),
          onExit: (_) => _hide(),
          child: Material(
            elevation: 8,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(widget.badgeInfo.icon, size: 16, color: badgeColor),
                      const SizedBox(width: 6),
                      Text(
                        widget.keyName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 14),
                        tooltip: 'Gesamtes Objekt kopieren',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: widget.data.toString()));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('In die Zwischenablage kopiert!'), duration: Duration(seconds: 1)),
                          );
                        },
                      ),
                      if (_isPinnedByClick)
                        IconButton(
                          icon: const Icon(Icons.close, size: 14),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() {
                            _isPinnedByClick = false;
                            _hide();
                          }),
                        ),
                    ],
                  ),
                  const Divider(height: 12),
                  ...widget.data.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 90,
                            child: Text(
                              entry.key,
                              style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                            ),
                          ),
                          Expanded(
                            child: SelectableText(
                              entry.value?.toString() ?? 'null',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

---

## 4. Integration in den bestehenden Tree- und Table-Viewer

Erweitere den `SmartNodeViewer`: Bevor ein JSON-Knoten rekursiv expandiert wird, prüft das System, ob es sich um ein komprimierbares Verbundobjekt handelt:

```dart
// Im SmartNodeViewer / Node-Builder:
if (value is Map<String, dynamic>) {
  final formattedBadge = EntityFormatterRegistry.tryFormat(value);
  if (formattedBadge != null) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: SmartCompositeBadge(
        keyName: keyName,
        data: value,
        badgeInfo: formattedBadge,
      ),
    );
  }

  return ExpansionTile(
    title: Text(keyName),
    children: (value).entries.map((e) => SmartNodeViewer(keyName: e.key, value: e.value)).toList(),
  );
}
```

---

## 5. Vor- und Nachteile im Überblick

| Kriterium | Traditioneller Tree-View | Reiner Text-Tooltip | Smart Badge mit Popover (Empfehlung) |
| :--- | :--- | :--- | :--- |
| **Höhenbedarf im UI** | Sehr hoch (1 Zeile pro Feld) | Minimal (1 Zeile) | Minimal (1 Zeile / Inline-Chip) |
| **Erfassbarkeit** | Mittel (Suchaufwand in Keys) | Schwer (Rohdaten) | **Sofort lesbar** (`Icon + Format`) |
| **Text kopierbar?** | Ja | ❌ Nein (bricht bei Mausbewegung ab) | **✅ Ja** (SelectableText & Copy-Button) |
| **Verhalten in Tabellenzellen** | Bricht Zeilenhöhe auf | Text wird abgeschnitten | **Perfekt als Zelleintrag geeignet** |
| **Skalierbarkeit** | Unübersichtlich ab 20 Keys | Gut | **Hervorragend** durch Heuristiken erweiterbar |

---

## 6. Such-Optimierung: "Context Windowing" für lange Listen (Treffer $\pm 1$)

### 6.1 Das Problem & das "Akkordeon-Fenster"-Konzept
Im modalen Screenshot 1 ist zu sehen: Die gesuchte ID befindet sich bei `leistungen[14].sortOrders[4].transportId`. 
- Wenn `leistungen` 30 Einträge hat, scrollt sich der Analyst durch `leistungen[0]` bis `leistungen[13]`, obwohl nur Index `14` gesucht wird.
- **Lösung:** Beim Filtern/Suchen zerlegt das UI die Liste dynamisch in **Sichtbarkeits-Segmente**:
  - `[0 .. 12]`: Zusammengeklappt zu einem Button `▾ 13 vorherige Elemente anzeigen (Index 0–12)`
  - `[13]`: Vollständig gerendert als **Vorheriges Element (Kontext)**
  - `[14]`: **Der Treffer** (hervorgehoben mit farbigem Border, auto-expandiert bis zur Fundstelle)
  - `[15]`: Vollständig gerendert als **Nachfolgendes Element (Kontext)**
  - `[16 .. N]`: Zusammengeklappt zu `▾ 15 nachfolgende Elemente anzeigen (Index 16–30)`

```
┌────────────────────────────────────────────────────────┐
│  leistungen [30 Einträge]       (Treffer bei Index 14) │
├────────────────────────────────────────────────────────┤
│  [+] 13 vorherige Einträge ausblenden (0 bis 12)       │
│  ───────────────────────────────────────────────────── │
│  ► [13] leistungId: "b3635..." (Kontext vorab)         │
│  ▼ [14] MATCH 🎯 leistungId: "c0a2f..." (TREFFER)      │
│      ► sortOrders [5 Einträge]                         │
│          ► [3] ...                                     │
│          ▼ [4] transportId: "a1a316b3-a493-..." ◄ MATCH│
│  ► [15] leistungId: "7fa01..." (Kontext nachfolgend)   │
│  ───────────────────────────────────────────────────── │
│  [+] 15 nachfolgende Einträge ausblenden (16 bis 29)   │
└────────────────────────────────────────────────────────┘
```

---

### 6.2 Berechnungslogik: Segmentierung einer Liste (`ContextWindowCalculator`)

```dart
import 'dart:math';

sealed class ListSegment {
  const ListSegment();
}

class VisibleItemSegment extends ListSegment {
  final int index;
  final bool isDirectMatch;

  VisibleItemSegment({required this.index, required this.isDirectMatch});
}

class CollapsedRangeSegment extends ListSegment {
  final int startIndex;
  final int endIndex; // inklusive
  int get count => (endIndex - startIndex) + 1;

  CollapsedRangeSegment({required this.startIndex, required this.endIndex});
}

class ContextWindowCalculator {
  static List<ListSegment> calculateSegments({
    required int totalLength,
    required Set<int> matchIndices,
    int radius = 1,
    bool forceShowAll = false,
  }) {
    if (totalLength == 0) return [];
    if (forceShowAll || matchIndices.isEmpty) {
      return List.generate(
        totalLength,
        (i) => VisibleItemSegment(index: i, isDirectMatch: matchIndices.contains(i)),
      );
    }

    final visibleIndices = <int>{};
    for (final match in matchIndices) {
      final start = max(0, match - radius);
      final end = min(totalLength - 1, match + radius);
      for (int i = start; i <= end; i++) {
        visibleIndices.add(i);
      }
    }

    final segments = <ListSegment>[];
    int currentIndex = 0;

    while (currentIndex < totalLength) {
      if (visibleIndices.contains(currentIndex)) {
        segments.add(VisibleItemSegment(
          index: currentIndex,
          isDirectMatch: matchIndices.contains(currentIndex),
        ));
        currentIndex++;
      } else {
        int collapsedStart = currentIndex;
        while (currentIndex < totalLength && !visibleIndices.contains(currentIndex)) {
          currentIndex++;
        }
        segments.add(CollapsedRangeSegment(
          startIndex: collapsedStart,
          endIndex: currentIndex - 1,
        ));
      }
    }

    return segments;
  }
}
```

---

### 6.3 Das Flutter UI-Widget: `SmartContextArrayViewer`

```dart
import 'package:flutter/material.dart';

class SmartContextArrayViewer extends StatefulWidget {
  final String arrayKey;
  final List<dynamic> items;
  final String searchQuery;
  final Widget Function(BuildContext context, int index, dynamic item, bool isMatch) itemBuilder;

  const SmartContextArrayViewer({
    super.key,
    required this.arrayKey,
    required this.items,
    required this.searchQuery,
    required this.itemBuilder,
  });

  @override
  State<SmartContextArrayViewer> createState() => _SmartContextArrayViewerState();
}

class _SmartContextArrayViewerState extends State<SmartContextArrayViewer> {
  bool _forceShowAll = false;
  final Set<int> _manuallyExpandedRanges = {};

  Set<int> _findMatches() {
    if (widget.searchQuery.trim().isEmpty) return {};
    final query = widget.searchQuery.toLowerCase();
    final matches = <int>{};

    for (int i = 0; i < widget.items.length; i++) {
      final itemStr = widget.items[i].toString().toLowerCase();
      if (itemStr.contains(query)) {
        matches.add(i);
      }
    }
    return matches;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matchIndices = _findMatches();
    final hasSearch = widget.searchQuery.trim().isNotEmpty;
    final totalCount = widget.items.length;

    final segments = ContextWindowCalculator.calculateSegments(
      totalLength: totalCount,
      matchIndices: matchIndices,
      radius: 1,
      forceShowAll: _forceShowAll || !hasSearch,
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(
          color: matchIndices.isNotEmpty
              ? Colors.amber.shade400.withValues(alpha: 0.6)
              : theme.dividerColor.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: matchIndices.isNotEmpty
                  ? Colors.amber.shade50.withValues(alpha: 0.5)
                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.data_array,
                  size: 16,
                  color: matchIndices.isNotEmpty ? Colors.amber.shade900 : Colors.blueGrey,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.arrayKey,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$totalCount Elemente',
                    style: const TextStyle(fontSize: 11, color: Colors.black82),
                  ),
                ),
                if (hasSearch && matchIndices.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${matchIndices.length} Treffer (Fokus: Treffer ±1)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown.shade900,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (hasSearch && matchIndices.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: () => setState(() => _forceShowAll = !_forceShowAll),
                    icon: Icon(
                      _forceShowAll ? Icons.filter_alt : Icons.unfold_more,
                      size: 14,
                    ),
                    label: Text(
                      _forceShowAll ? 'Auf Treffer reduzieren' : 'Alle $totalCount zeigen',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          ...segments.map((segment) {
            return switch (segment) {
              VisibleItemSegment(:final index, :final isDirectMatch) =>
                _buildVisibleItem(context, index, isDirectMatch),
              CollapsedRangeSegment(:final startIndex, :final endIndex, :final count) =>
                _buildCollapsedPlaceholder(startIndex, endIndex, count),
            };
          }),
        ],
      ),
    );
  }

  Widget _buildVisibleItem(BuildContext context, int index, bool isDirectMatch) {
    final item = widget.items[index];

    return Container(
      decoration: BoxDecoration(
        color: isDirectMatch ? Colors.amber.shade50.withValues(alpha: 0.3) : null,
        border: Border(
          left: BorderSide(
            color: isDirectMatch ? Colors.orange : Colors.transparent,
            width: 4,
          ),
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            child: Text(
              '[$index]',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: isDirectMatch ? FontWeight.bold : FontWeight.normal,
                color: isDirectMatch ? Colors.orange.shade900 : Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: widget.itemBuilder(context, index, item, isDirectMatch),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedPlaceholder(int start, int end, int count) {
    final rangeKey = '$start-$end';
    final isLocallyExpanded = _manuallyExpandedRanges.contains(rangeKey.hashCode);

    if (isLocallyExpanded) {
      return Column(
        children: [
          Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  'Index $start bis $end (eingeblendet)',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => setState(() => _manuallyExpandedRanges.remove(rangeKey.hashCode)),
                  child: const Text('Wieder einklappen', style: TextStyle(fontSize: 11, color: Colors.blue)),
                ),
              ],
            ),
          ),
          ...List.generate(count, (offset) {
            final idx = start + offset;
            return _buildVisibleItem(context, idx, false);
          }),
        ],
      );
    }

    return InkWell(
      onTap: () => setState(() => _manuallyExpandedRanges.add(rangeKey.hashCode)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
        color: Colors.grey.shade50,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.more_horiz, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              '… $count verborgene Elemente (Index $start bis $end) anzeigen',
              style: TextStyle(
                fontSize: 11,
                color: Colors.blueGrey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

### 6.4 Auto-Scroll & Deep-Highlighting (Fokus auf den Treffer)

```dart
void scrollToMatch(GlobalKey matchKey) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (matchKey.currentContext != null) {
      Scrollable.ensureVisible(
        matchKey.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
    }
  });
}
```

---

## 7. Zusammenfassung der kombinierten UX-Mechaniken

1. **Suchfeld-Eingabe:** Nutzer tippt eine UUID oder Leistung-ID ein.
2. **Auto-Filter & Auto-Expand:** Der Tree klappt alle Pfade bis zum Treffer automatisch auf.
3. **Context-Windowing (Abschnitt 6):** Bei Listen wie `leistungen` (30 Elemente) werden automatisch nur der Treffer selbst (z. B. Index 14) sowie Index 13 und Index 15 gezeigt. Vorangehende (`0..12`) und nachfolgende (`16..29`) Elemente werden zu kompakten Platzhaltern komprimiert.
4. **Smart Badges (Abschnitt 2 & 3):** Komplexe Verbundobjekte wie Adressen oder Zeitfenster innerhalb der Trefferzeile bleiben einzeilige Chips und überladen das Bild nicht.
5. **Auto-Center:** Die Trefferzeile springt per `ensureVisible` weich in die vertikale Mitte des Bildschirms.

---

## 8. Gesamt-UX-Architektur: Überführung in ein kohärentes Workspace-Erlebnis

### 8.1 Die Problemursache der aktuellen UI-Fragmentierung

Betrachtet man die vier Screenshots im Zusammenhang, wird klar, warum sich das System uneinheitlich anfühlt:

```
[Screenshot 4: Tabellenansicht]     [Screenshot 2: Timeline-Rail]      [Screenshot 3: Diff-Ansicht]
       │                                     │                                      │
       ▼                                     ▼                                      ▼
 (Tabelle schneidet                    (Große vertikale                       (Wieder ein anderer
  JSON-Strings ab)                      Abstände, Text-JSON)                   Screen für Änderungen)
       │                                     │                                      │
       └──────────────────────────┬──────────┴──────────────────────────────────────┘
                                  ▼
                     [Screenshot 1: Modaler Dialog]
                 (Blockiert den Bildschirm, reißt den
                  Nutzer komplett aus dem Arbeitsfluss)
```

1. **Modal Break:** Wenn der Analyst eine Message anklickt, um die Details zu sehen, öffnet sich ein zentriertes Vollbild-Modal. Man verliert den Bezug zu den Vorgänger- und Nachfolger-Nachrichten im Stream. Um die nächste Nachricht zu prüfen, muss das Modal geschlossen, die nächste Zeile geklickt und das nächste Modal geöffnet werden.
2. **Redundante Darstellung von Roh-JSON:** Sowohl in der Tabelle (Spalte `Content`) als auch in der Timeline wird roher JSON-Text dargestellt. Keiner der beiden Screens nutzt das Domänenwissen aus.
3. **Getrennte Zustände:** Filter und Suchen werden pro Screen neu gedacht, anstatt dasselbe konsistente Datenmodell zu steuern.

---

### 8.2 Das Zielmodell: Das 3-Zonen "Observability Cockpit"

Statt zwischen isolierten Vollbild-Modi hin- und herzuschalten, wird das UI als **ein zusammenhängender Desktop-Arbeitsplatz** mit drei synchronisierten Zonen aufgebaut:

```
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ TOPBAR: Global Search ("transportId: a1a3..."), Preset Selector, Run Actions, Status                 │
├───────────────────┬─────────────────────────────────────────────────┬──────────────────────────────────┤
│ ZONE 1: CONTEXT   │ ZONE 2: MASTER STREAM                           │ ZONE 3: LIVE INSPECTOR           │
│ (Collapsible)     │ (Timeline OR Table View)                        │ (Ersetzt das Modal vollständig!) │
│                   │                                                 │                                  │
│ 📁 Skripte        │ [  Timeline  |  Table  ]  ──  Layout Switches   │ [ Smart Tree | Raw | Diff ]      │
│ ⚙️ Topics         │                                                 │                                  │
│ 🏷️ Filter         │ 10:47:05 ● Topic A  [Kennz: HR099864] [🚚 3 L.] │ ┌──────────────────────────────┐ │
│                   │ 10:48:20 ● Topic B  [Kennz: JAN21   ] [📍 Wien] │ │ Smart Badges                   │ │
│                   │ 10:50:00 ➔ Topic B  [Kennz: JAN21   ] [🎯 MATCH]│ │ Context Windowing (±1)         │ │
│                   │ 10:52:15 ● Topic C  [Kennz: JAN33   ] [⏱ Zeit] │ │ Quick-Action: "Add to Columns" │ │
│                   │                                                 │ └──────────────────────────────┘ │
│                   │ ◄ Mit Pfeiltasten (↑/↓) sofort durchsteppbar ► │ Details aktualisieren sich live! │
└───────────────────┴─────────────────────────────────────────────────┴──────────────────────────────────┘
```

#### Die drei Zonen im Detail:

1. **Zone 1 (Links - Navigation & Filter):**
   - Behält deine bestehende Skriptliste bei, kann aber mit einem Klick auf ein Icon links auf 48px Breite minimiert werden, um horizontalen Platz freizugeben.
2. **Zone 2 (Mitte - Master Stream):**
   - **Hier findet der Paradigmenwechsel statt:** Timeline und Tabelle sind **keine unterschiedlichen App-Seiten**, sondern lediglich **zwei Darstellungsformen derselben Nachrichtensequenz**.
   - Beide Darstellungsformen nutzen dieselben **Smart Badges**! In der Tabelle steht in der Zelle nicht `{"strasse": "...", "ort": "..."}`, sondern das Badge `📍 Musterstraße 12, Wien`.
   - Die aktuell ausgewählte Zeile hat einen klaren Tastaturfokus (Active State).
3. **Zone 3 (Rechts - Live Inspector Side-Sheet):**
   - **Das Modal aus Screenshot 1 wird restlos eliminiert.**
   - Stattdessen öffnet sich rechts ein fest angedockter Inspector (z. B. 40–50 % der Fensterbreite, per Divider verschiebbar).
   - Sobald der Nutzer in Zone 2 mit den Pfeiltasten `↑` und `↓` durch die Liste wandert, rendert Zone 3 in Echtzeit die Details der fokussierten Message.
   - Oben im Inspector gibt es drei Reiter:
     - **Smart Tree:** Der optimierte Baum mit Context-Windowing ($\pm 1$), Smart Badges und Breadcrumbs.
     - **Diff-Ansicht:** Zeigt sofort das Delta zur unmittelbar vorherigen Message desselben Identifiers (ersetzt Screenshot 3!).
     - **Raw JSON:** Für den schnellen Export oder Copy-Paste.

---

### 8.3 Vereinheitlichung der Spezial-Views

| Bisheriger Zustand | Problem | Kohärente Lösung im Cockpit |
| :--- | :--- | :--- |
| **Screenshot 1 (Modal)** | Blockiert Übersicht, langsamer Quervergleich | **Rechtes Inspector-Panel:** Bleibt offen; wechselt blitzschnell beim Navigieren durch Zeilen. |
| **Screenshot 2 (Timeline)** | Vertikal lang, unstrukturierte JSON-Strings | **Master Stream (Modus "Timeline"):** Die vertikale Schiene bleibt erhalten, aber die Cards zeigen kompakte Key-Value-Badges statt rohem JSON. |
| **Screenshot 3 (Diffs)** | Eigener Screen; schwer zu vergleichen | **Inspector-Tab "Diff":** Jeder Klick auf eine Message kann sofort das Delta zur Vorgänger-Message farbig (Rot/Grün) im Seitenpanel anzeigen. |
| **Screenshot 4 (Tabelle)** | JSON in Spalte `Content` abgeschnitten | **Master Stream (Modus "Table"):** Spalten sind konfigurierbar; strukturierte Felder werden als Smart-Chips inline gerendert. |

---

### 8.4 Cross-Cutting Workflows (Die "Klebstoff"-Features)

Damit sich das System wie aus einem Guss anfühlt, verbinden drei Interaktionsmechaniken alle Ansichten:

#### A. "Click-to-Column" (Vom Detail zur Übersicht)
Ein Nutzer sieht im rechten Inspector-Baum einen spannenden Wert, z. B. `sortOrders[0].value`.
- Ein Rechtsklick oder Icon daneben bietet: *"Als Spalte im Master anheften"*.
- Sofort blendet die Tabelle in Zone 2 eine neue Spalte mit genau diesem Wert für alle sichtbaren Zeilen ein.
- Gespeichert wird dies im **Preset** des jeweiligen Topics/Skripts.

#### B. Unified Search & Global Focus
Die Suche in der Topbar steuert beide Zonen gleichzeitig:
1. In Zone 2 (Master) werden Zeilen, die den Begriff enthalten, hervorgehoben (oder gefiltert).
2. Der Inspector in Zone 3 springt sofort per Context-Windowing ($\pm 1$) genau auf den passenden JSON-Pfad im ausgewählten Datensatz.

#### C. Nahtlose Tastaturnavigation
- `J` / `K` oder `↓` / `↑`: Vorherige / Nächste Message in der Liste auswählen.
- `Tab`: Fokus wechselt in den Inspector, um durch Suchtreffer zu springen.
- `Esc`: Schließt den Inspector (oder klappt Zone 1 wieder auf).

---

### 8.5 Flutter-Architektur für den Unified Workspace

Um diese Struktur performant und wartbar umzusetzen, benötigst du einen zentralen Workspace-State und ein Layout, das Split-Screen unterstützt.

#### 1. Der Workspace State Controller

```dart
import 'package:flutter/foundation.dart';

enum MasterViewMode { timeline, table }
enum InspectorTab { smartTree, diff, rawJson }

class KafkaMessageItem {
  final String id;
  final DateTime timestamp;
  final String topic;
  final int partition;
  final int offset;
  final String key;
  final Map<String, dynamic> payload;

  KafkaMessageItem({
    required this.id,
    required this.timestamp,
    required this.topic,
    required this.partition,
    required this.offset,
    required this.key,
    required this.payload,
  });
}

class WorkspaceStateController extends ChangeNotifier {
  MasterViewMode viewMode = MasterViewMode.timeline;
  InspectorTab activeInspectorTab = InspectorTab.smartTree;
  
  bool isNavigationExpanded = true;
  bool isInspectorOpen = true;

  String searchQuery = '';
  List<KafkaMessageItem> messages = [];
  int selectedIndex = 0;

  KafkaMessageItem? get selectedMessage =>
      (messages.isNotEmpty && selectedIndex >= 0 && selectedIndex < messages.length)
          ? messages[selectedIndex]
          : null;

  KafkaMessageItem? get previousMessage =>
      (selectedIndex > 0 && selectedIndex < messages.length)
          ? messages[selectedIndex - 1]
          : null;

  void selectMessage(int index) {
    if (index >= 0 && index < messages.length) {
      selectedIndex = index;
      isInspectorOpen = true; // Automatisch öffnen bei Auswahl
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    searchQuery = query;
    notifyListeners();
  }

  void toggleViewMode() {
    viewMode = viewMode == MasterViewMode.timeline ? MasterViewMode.table : MasterViewMode.timeline;
    notifyListeners();
  }

  void toggleInspector() {
    isInspectorOpen = !isInspectorOpen;
    notifyListeners();
  }
}
```

---

#### 2. Das Haupt-Workspace-Layout (`WorkspaceScaffold`)

Dieses Widget ersetzt die isolierten Seiten durch ein responsives Drei-Zonen-Grid mit Tastatur-Steuerung:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WorkspaceScaffold extends StatefulWidget {
  final WorkspaceStateController controller;

  const WorkspaceScaffold({super.key, required this.controller});

  @override
  State<WorkspaceScaffold> createState() => _WorkspaceScaffoldState();
}

class _WorkspaceScaffoldState extends State<WorkspaceScaffold> {
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKey.arrowDown || event.logicalKey == LogicalKey.keyJ) {
      widget.controller.selectMessage(widget.controller.selectedIndex + 1);
    } else if (event.logicalKey == LogicalKey.arrowUp || event.logicalKey == LogicalKey.keyK) {
      widget.controller.selectMessage(widget.controller.selectedIndex - 1);
    } else if (event.logicalKey == LogicalKey.escape) {
      if (widget.controller.isInspectorOpen) {
        widget.controller.toggleInspector();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;

        return KeyboardListener(
          focusNode: _keyboardFocusNode,
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: Scaffold(
            appBar: _buildWorkspaceAppBar(ctrl),
            body: Row(
              children: [
                // ZONE 1: Navigation / Script Context
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: ctrl.isNavigationExpanded ? 260 : 56,
                  child: _buildNavigationPanel(ctrl),
                ),
                const VerticalDivider(width: 1),

                // ZONE 2: Master Stream (Timeline oder Table)
                Expanded(
                  flex: ctrl.isInspectorOpen ? 5 : 10,
                  child: _buildMasterContent(ctrl),
                ),

                // ZONE 3: Live Inspector (anstatt des Modals)
                if (ctrl.isInspectorOpen && ctrl.selectedMessage != null) ...[
                  const VerticalDivider(width: 1),
                  Expanded(
                    flex: 5,
                    child: _buildInspectorPanel(ctrl),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildWorkspaceAppBar(WorkspaceStateController ctrl) {
    return AppBar(
      titleSpacing: 16,
      title: SizedBox(
        height: 40,
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Nachrichten filtern (z. B. Kennzeichen, UUID, Leistungs-ID)...',
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon: ctrl.searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () => ctrl.setSearchQuery(''),
                  )
                : null,
            contentPadding: EdgeInsets.zero,
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
          onChanged: ctrl.setSearchQuery,
        ),
      ),
      actions: [
        // Umschalter: Timeline vs. Table
        SegmentedButton<MasterViewMode>(
          segments: const [
            ButtonSegment(value: MasterViewMode.timeline, icon: Icon(Icons.timeline, size: 16), label: Text('Timeline')),
            ButtonSegment(value: MasterViewMode.table, icon: Icon(Icons.table_chart, size: 16), label: Text('Tabelle')),
          ],
          selected: {ctrl.viewMode},
          onSelectionChanged: (set) => ctrl.toggleViewMode(),
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
        ),
        const SizedBox(width: 12),
        IconButton(
          icon: Icon(ctrl.isInspectorOpen ? Icons.vertical_split : Icons.vertical_split_outlined),
          tooltip: 'Inspector ein-/ausblenden',
          onPressed: ctrl.toggleInspector,
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildNavigationPanel(WorkspaceStateController ctrl) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.folder_open, size: 20),
            title: ctrl.isNavigationExpanded ? const Text('Skripte & Jobs') : null,
            trailing: IconButton(
              icon: Icon(ctrl.isNavigationExpanded ? Icons.chevron_left : Icons.chevron_right),
              onPressed: () => setState(() => ctrl.isNavigationExpanded = !ctrl.isNavigationExpanded),
            ),
          ),
          const Divider(height: 1),
          // Hier deine bestehende Skriptliste einhängen...
        ],
      ),
    );
  }

  Widget _buildMasterContent(WorkspaceStateController ctrl) {
    if (ctrl.viewMode == MasterViewMode.timeline) {
      // Dein optimierter Timeline-Stream mit Smart Badges
      return ListView.builder(
        itemCount: ctrl.messages.length,
        itemBuilder: (context, index) {
          final isSelected = index == ctrl.selectedIndex;
          final msg = ctrl.messages[index];
          return ListTile(
            selected: isSelected,
            selectedTileColor: Colors.blue.withValues(alpha: 0.08),
            onTap: () => ctrl.selectMessage(index),
            leading: Text('[${msg.offset}]', style: const TextStyle(fontFamily: 'monospace')),
            title: Text('${msg.key} — ${msg.topic}'),
            subtitle: Text(msg.timestamp.toIso8601String()),
          );
        },
      );
    } else {
      // Deine konfigurierbare Tabellenansicht mit Smart Badges
      return const Center(child: Text('Projektierte Tabelle mit Inline Smart-Chips'));
    }
  }

  Widget _buildInspectorPanel(WorkspaceStateController ctrl) {
    final msg = ctrl.selectedMessage!;

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          // Inspector Header mit schnellem Schließen und Copy
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Message: ${msg.key}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('Offset: ${msg.offset} • Partition: ${msg.partition}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: ctrl.toggleInspector,
                ),
              ],
            ),
          ),

          // Tabs: Smart Tree, Diff zum Vorgänger, Raw JSON
          Expanded(
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Smart Tree'),
                      Tab(text: 'Diff (Delta)'),
                      Tab(text: 'Raw JSON'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // TAB 1: Smart Tree mit Smart Badges & Context Windowing
                        SmartContextArrayViewer(
                          arrayKey: 'Payload Details',
                          items: [msg.payload],
                          searchQuery: ctrl.searchQuery,
                          itemBuilder: (ctx, i, item, isMatch) => Text(item.toString()),
                        ),
                        // TAB 2: Integrierte Diff-Ansicht (ersetzt Screenshot 3)
                        Center(
                          child: Text(
                            ctrl.previousMessage != null
                                ? 'Delta zu Offset ${ctrl.previousMessage!.offset}'
                                : 'Keine vorherige Nachricht zum Vergleich.',
                          ),
                        ),
                        // TAB 3: Rohes JSON
                        SelectableText(msg.payload.toString()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

---

### 8.6 Roadmap: Schritt-für-Schritt-Migration

Um diese Umstellung ohne Unterbrechung deiner Entwicklungsarbeit durchzuführen:

1. **Schritt 1: Modal durch Side-Sheet ersetzen (Höchster ROI)**
   - Baue das `showDialog(...)` um in ein rechts angedocktes `Container`/`AnimatedContainer`. 
   - Allein dieser Schritt beseitigt das lästige Öffnen/Schließen von 10 Modals hintereinander.
2. **Schritt 2: Badge-Formatter einbinden**
   - Binde den `SmartCompositeBadge` in deine Zeilenanzeigen ein. Dadurch verschwinden unlesbare JSON-Fragmente wie `{"kennzeichen": "JAN21", ...}` und werden zu kompakten Status-Tags.
3. **Schritt 3: Diff-Screen als Tab in den Inspector integrieren**
   - Statt Screenshot 3 als eigene Seite aufzurufen, übergibst du `messages[currentIndex]` und `messages[currentIndex - 1]` an den neuen Inspector-Tab *"Diff"*.
4. **Schritt 4: Tastatursteuerung aktivieren**
   - Mit Pfeiltaste `Runter` durch die Messages gehen und sehen, wie der rechte Inspector synchron im Millisekundentakt mitwandert.

---

## 9. Ergonomie & Responsive Adaption: Die Lösung für Laptop-Bildschirme

Dein Feedback trifft genau den wunden Punkt klassischer Side-Sheets:
> **Auf typischen Laptop-Displays (13–15 Zoll, 1920×1080 mit 125 % oder 150 % OS-Skalierung)** stehen effektiv oft nur **1280 bis 1536 logische Pixel** in der Breite zur Verfügung. 
> Zieht man 260 px Navigation ab, bleiben ca. 1000–1200 px übrig. Ein 50/50 Split lässt der Haupttabelle nur 500–600 px (Spalten werden brutal abgeschnitten) und dem Inspector ebenfalls nur 500–600 px (tiefe JSON-Einrückungen brechen unlesbar um).

Professionelle Entwickler- und Observability-Werkzeuge (z. B. **Chrome DevTools, Datadog Log Stream, Postman, VS Code**) lösen genau diese Platzklemme durch **vier adaptive Ergonomie-Mechanismen**, die du in Flutter einsetzen kannst:

---

### 9.1 Die 4 Lösungsstrategien im Detail

```
STRATEGIE 1: DOCK BOTTOM (Horizontaler Split)     STRATEGIE 2: FOCUS MODE (Mit Inline-Stepper)
┌──────────────────────────────────────────────┐  ┌──────────────────────────────────────────────┐
│ TOPBAR                                       │  │ TOPBAR                                       │
├─────────┬────────────────────────────────────┤  ├─────────┬────────────────────────────────────┤
│ Nav     │ Master-Tabelle (Volle Breite!)     │  │ Nav     │ [◄] Nachricht 14 von 42 [►] (Esc)  │
│ (Rail)  │ Col 1 | Col 2 | Col 3 | Col 4      │  │ (Rail)  ├────────────────────────────────────┤
│ 48px    │ ...                                │  │ 48px    │ SMART TREE (100% Breite!)          │
├─────────┴────────────────────────────────────┤  │         │ leistungen[14]                     │
│ INSPECTOR (Unten angedockt, 350px hoch)      │  │         │   └── sortOrders[4]                │
│ [Smart Tree] [Diff] [Raw]                    │  │         │         └── transportId: "a1a3..." │
└──────────────────────────────────────────────┘  └─────────┴────────────────────────────────────┘
```

#### Strategie 1: Adaptives Docking (Side vs. Bottom Split – wie Chrome DevTools)
- **Warum Bottom-Docking auf Laptops überlegen ist:**
  - Tabellen und Kafka-Streams wachsen **in die Breite** (sie brauchen 6–10 Spalten ohne horizontales Scrollen).
  - JSON-Payloads und Listen wachsen **in die Tiefe** (vertikal).
  - Ist der Inspector unten angedockt (z. B. 320–380 px Höhe), behält deine Tabelle oben **100 % der horizontalen Bildschirmbreite**. Im Inspector unten hat der JSON-Tree ebenfalls die volle Breite – selbst 10-fach geschachtelte Strukturen werden niemals horizontal abgeschnitten.
- **Benutzerkontrolle:** Ein einfaches Toggle-Icon im Inspector-Header erlaubt es dem Nutzer, zwischen **„Rechts andocken“** (für 27"-Monitore), **„Unten andocken“** (für Laptops) und **„Vollbild“** zu wechseln.

---

#### Strategie 2: "Focus Mode" mit Inline-Stepper (Ersetzt das modale Dilemma)
Ein modaler Dialog ist nur deshalb schlecht, weil er **statisch isoliert** ist: Man kann nicht zur nächsten Nachricht wechseln, ohne ihn zu schließen.
- Wenn der Laptop-Screen zu klein für jeden Split ist, gibt es den **Focus Mode**:
  - Der Inspector nimmt mit einem Klick auf ein Maximize-Icon (oder Shortcut `Space` / `F`) **die gesamte Arbeitsfläche (100 % Breite & Höhe)** ein.
  - **Der entscheidende UX-Unterschied zum alten Modal:**
    Oben im Header des Maximized Inspectors befindet sich eine permanente **Streaming-Kompaktsteuerung**:
    ```
    [◄ Vorherige (K)]    Nachricht 14 von 42  [Offset: 29775751]    [Nächste (J) ►]    [ ✕ Minimieren (Esc) ]
    ```
  - Der Nutzer profitiert von der **vollen Displaybreite für das tiefe JSON**, kann aber weiterhin mit `J` / `K` oder den Pfeiltasten durch alle 42 Treffer steppen, ohne den Fokus zu verlieren!

---

#### Strategie 3: Auto-Collapse der Navigation (Zone 1)
- Auf Screens mit weniger als $1400\,\text{px}$ Breite (oder sobald ein Inspector geöffnet wird) klappt Zone 1 (Skripte) automatisch von $260\,\text{px}$ auf eine **Icon-Only-Rail mit $48\,\text{px}$** zusammen.
- Allein das gewinnt sofort über $200\,\text{px}$ zusätzlichen horizontalen Arbeitsraum für die Daten.

---

#### Strategie 4: Indentation Flattening (Kompaktierung tiefer JSON-Pfade)
Auf kleinen Screens frisst eine Standard-Einrückung von $16\,\text{px}$ pro Ebene bei Level 8 bereits $128\,\text{px}$ Rand.
- **Flattened Path Rendering:** Wenn ein Objekt nur eine Sub-Struktur enthält, rücke nicht 4-mal ein, sondern fasse den Pfad inline zusammen:
  - ❌ Statt:
    ```
    ▼ leistungen
        ▼ [14]
            ▼ sortOrders
                ▼ [4]
                    transportId: "a1a3..."
    ```
  - ✅ Rendere auf kompakten Displays:
    ```
    ▼ leistungen[14] . sortOrders[4]
        transportId: "a1a316b3-a493-..."
    ```
  - Das spart über 60 % der horizontalen Breite im Tree!

---

### 9.2 Layout-Entscheidungsmatrix nach Viewport

| Display / Fensterbreite | Standard-Modus | Zone 1 (Nav) | Zone 2 & 3 Verhalten |
| :--- | :--- | :--- | :--- |
| **Großbildschirm (> 1500 px)** | **Side-by-Side** (Rechts angedockt) | Ausgeklappt (260 px) | 50% Master-Tabelle, 50% Inspector nebeneinander |
| **Laptop Standard (1200 – 1500 px)** | **Bottom-Dock** oder **Side-Overlay** | Kompakt-Rail (48 px) | Tabelle 100% Breite (oben), Inspector 100% Breite (unten, 340 px) |
| **Kompakt (< 1200 px / halbes Fenster)** | **Focus Mode mit Stepper** | Ausgeblendet / Drawer | Vollbild-Inspector mit Schnell-Navigation (`←` / `→`) |

---

### 9.3 Erweiterter Workspace State Controller & Flutter-Widget

Hier ist die aktualisierte Architektur, die **Bottom-Docking**, **Side-Docking** und den **Focus Mode mit Tastatur-Stepper** nahtlos vereint:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Die drei ergonomischen Andock-Modi für unterschiedliche Bildschirmgrößen
enum InspectorDockPosition {
  right,   // Großes Display: Side-by-Side Split
  bottom,  // Laptop-Display: Tabelle oben (100% Breite), Inspector unten
  maximized // Laptop Fokus-Modus: 100% Arbeitsfläche mit Nachrichten-Stepper
}

class ResponsiveWorkspaceController extends ChangeNotifier {
  MasterViewMode viewMode = MasterViewMode.table;
  InspectorTab activeInspectorTab = InspectorTab.smartTree;
  
  InspectorDockPosition dockPosition = InspectorDockPosition.bottom; // Perfekter Default für Laptops!
  bool isInspectorOpen = false;
  bool isNavigationExpanded = false; // Auf Laptops standardmäßig platzsparend als Icon-Rail

  int selectedIndex = 0;
  List<KafkaMessageItem> messages = [];
  String searchQuery = '';

  KafkaMessageItem? get selectedMessage =>
      (messages.isNotEmpty && selectedIndex >= 0 && selectedIndex < messages.length)
          ? messages[selectedIndex]
          : null;

  bool get hasPrevious => selectedIndex > 0;
  bool get hasNext => selectedIndex < messages.length - 1;

  void selectMessage(int index) {
    if (index >= 0 && index < messages.length) {
      selectedIndex = index;
      isInspectorOpen = true;
      notifyListeners();
    }
  }

  void nextMessage() {
    if (hasNext) selectMessage(selectedIndex + 1);
  }

  void previousMessage() {
    if (hasPrevious) selectMessage(selectedIndex - 1);
  }

  void setDockPosition(InspectorDockPosition pos) {
    dockPosition = pos;
    notifyListeners();
  }

  void toggleInspector() {
    isInspectorOpen = !isInspectorOpen;
    notifyListeners();
  }

  void toggleMaximize() {
    if (dockPosition == InspectorDockPosition.maximized) {
      dockPosition = InspectorDockPosition.bottom;
    } else {
      dockPosition = InspectorDockPosition.maximized;
    }
    notifyListeners();
  }
}
```

---

### 9.4 Das adaptive Layout-Widget (`AdaptiveWorkspaceLayout`)

Dieses Widget wertet die Fensterbreite und die gewählte Docking-Position aus. Auf Laptops teilt es den Bildschirm wahlweise horizontal oder bietet den Vollbild-Fokusmodus mit Stepper:

```dart
class AdaptiveWorkspaceLayout extends StatelessWidget {
  final ResponsiveWorkspaceController ctrl;

  const AdaptiveWorkspaceLayout({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        // Automatische Anpassung bei kleineren Bildschirmen
        final isCompactScreen = screenWidth < 1400;

        return Row(
          children: [
            // ZONE 1: Navigation (auf Laptops automatisch schmale 48px Icon-Rail)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: (ctrl.isNavigationExpanded && !isCompactScreen) ? 240 : 52,
              child: _buildNavigationRail(context),
            ),
            const VerticalDivider(width: 1),

            // HAUPT-ARBEITSBEREICH (Zone 2 & Zone 3)
            Expanded(
              child: _buildAdaptiveWorkArea(context, isCompactScreen),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAdaptiveWorkArea(BuildContext context, bool isCompactScreen) {
    if (!ctrl.isInspectorOpen || ctrl.selectedMessage == null) {
      // Nur die Master-Ansicht (Tabelle oder Timeline)
      return _buildMasterContent();
    }

    // FALL 1: Focus Mode (Vollbild mit Stepper - perfekt für 13"-Laptops)
    if (ctrl.dockPosition == InspectorDockPosition.maximized) {
      return _buildMaximizedInspectorWithStepper(context);
    }

    // FALL 2: Laptop-Empfehlung -> Bottom-Dock (Horizontaler Split)
    if (ctrl.dockPosition == InspectorDockPosition.bottom) {
      return Column(
        children: [
          // Tabelle behält 100% der Breite! Keine abgeschnittenen Spalten
          Expanded(
            flex: 5,
            child: _buildMasterContent(),
          ),
          const Divider(height: 1),
          // Inspector unten mit voller Breite für tiefe JSON-Bäume
          SizedBox(
            height: 340,
            child: _buildInspectorContainer(context),
          ),
        ],
      );
    }

    // FALL 3: Side-by-Side Split (Rechts angedockt für breite Monitore)
    return Row(
      children: [
        Expanded(
          flex: isCompactScreen ? 5 : 6,
          child: _buildMasterContent(),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: isCompactScreen ? 5 : 4,
          child: _buildInspectorContainer(context),
        ),
      ],
    );
  }

  Widget _buildMaximizedInspectorWithStepper(BuildContext context) {
    final msg = ctrl.selectedMessage!;

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          // Fokus-Toolbar mit Nachrichten-Stepper & Escape-Hinweis
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Zurück zur Tabelle (Esc)',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => ctrl.setDockPosition(InspectorDockPosition.bottom),
                ),
                const SizedBox(width: 8),
                Text(
                  'Fokus-Modus: Nachricht [${msg.key}]',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Spacer(),
                // DER STEPPER: Wechselt die Message, ohne den Fullscreen-Modus zu verlassen!
                FilledButton.tonalIcon(
                  onPressed: ctrl.hasPrevious ? ctrl.previousMessage : null,
                  icon: const Icon(Icons.chevron_left, size: 16),
                  label: const Text('Vorherige (K)'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '${ctrl.selectedIndex + 1} von ${ctrl.messages.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: ctrl.hasNext ? ctrl.nextMessage : null,
                  icon: const Icon(Icons.chevron_right, size: 16),
                  label: const Text('Nächste (J)'),
                ),
                const SizedBox(width: 16),
                IconButton(
                  tooltip: 'Minimieren',
                  icon: const Icon(Icons.fullscreen_exit),
                  onPressed: ctrl.toggleMaximize,
                ),
              ],
            ),
          ),
          // Maximierte Detailansicht mit 100% Bildschirmbreite
          Expanded(child: _buildInspectorTabs(context)),
        ],
      ),
    );
  }

  Widget _buildInspectorContainer(BuildContext context) {
    return Column(
      children: [
        _buildInspectorHeader(context),
        Expanded(child: _buildInspectorTabs(context)),
      ],
    );
  }

  Widget _buildInspectorHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Colors.grey.withValues(alpha: 0.1),
      child: Row(
        children: [
          Text(
            'Message: ${ctrl.selectedMessage?.key}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const Spacer(),
          // Docking Umschalter
          IconButton(
            icon: Icon(
              ctrl.dockPosition == InspectorDockPosition.bottom
                  ? Icons.dock
                  : Icons.view_sidebar,
              size: 16,
            ),
            tooltip: ctrl.dockPosition == InspectorDockPosition.bottom
                ? 'Rechts andocken'
                : 'Unten andocken (Laptop-Modus)',
            onPressed: () {
              ctrl.setDockPosition(
                ctrl.dockPosition == InspectorDockPosition.bottom
                    ? InspectorDockPosition.right
                    : InspectorDockPosition.bottom,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.fullscreen, size: 18),
            tooltip: 'Fokus-Vollbild (mit Tastatur-Stepper)',
            onPressed: ctrl.toggleMaximize,
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            tooltip: 'Schließen (Esc)',
            onPressed: ctrl.toggleInspector,
          ),
        ],
      ),
    );
  }

  Widget _buildInspectorTabs(BuildContext context) {
    return const Center(child: Text('Smart Tree / Diff / Raw Tabs'));
  }

  Widget _buildMasterContent() {
    return const Center(child: Text('Master Stream: Tabelle mit voller Breite'));
  }

  Widget _buildNavigationRail(BuildContext context) {
    return Container(color: Colors.grey.shade50);
  }
}
```

---

## 10. Codebase-Analyse & Technisches Feedback: Abgleich mit dem Kafkalyzer-Istzustand

### 10.1 Gesamteinschätzung des Konzepts

Das vorliegende Konzept adressiert die realen Pain-Points beim Arbeiten mit komplexen, tief geschachtelten Kafka-Nachrichten im Logistik- und IoT-Umfeld punktgenau:
1. **Eliminierung des „Modal Break“:** Der Wechsel von blockierenden Vollbild-Dialogen (`MessageDetailsDialog`) zu einem fest verankerten Inspector (Bottom- oder Side-Dock sowie Focus-Mode) beseitigt die größte kognitive Reibung bei der sequentiellen Analyse mehrerer Nachrichten.
2. **Context Windowing ($\pm 1$):** Löst das Kernproblem unübersichtlicher Groß-Arrays (wie `leistungen[30]` mit Treffer bei Index 14), ohne den Nutzer durch manuelles Aufklappen und Scrollen zu überfordern.
3. **Smart Badges / Progressive Disclosure:** Schafft den Spagat zwischen unleserlichen JSON-Rohstrings und vertikal explodierenden Objektbäumen bei semantischen Verbundstrukturen (z. B. Adressen, Zeitspannen, Geo-Daten).
4. **Ergonomie für Laptop-Displays (Kapitel 9):** Die Erkenntnis, dass Side-by-Side-Splits auf typischen 13–15"-Geräten (1080p bei 125–150 % OS-Skalierung) an horizontalem Platzmangel scheitern und **Bottom-Docking** bzw. **Focus Mode mit Stepper** die überlegenen Modi sind, ist für die Praxis essenziell.

---

### 10.2 Detaillierter Abgleich mit der bestehenden Kafkalyzer-Architektur

Bei der Übertragung des Konzepts auf die reale Kafkalyzer-Codebase zeigen sich wertvolle Synergien, aber auch wichtige architektonische Rahmenbedingungen, die beachtet werden müssen:

#### 1. Verankerung in der Komponenten-Hierarchie: `MessagesView` statt globalem `WorkspaceScaffold`
- **Konzeptvorschlag (Kapitel 8):** Skizziert ein App-weites `WorkspaceScaffold`, das Skript-Navigation, Master-Stream und Inspector in einem globalen Widget zusammenfasst.
- **Codebase-Istzustand:**
  - Kafkalyzer besitzt bereits eine modulare Multi-Feature-Architektur:
    - [`MainLayout`](file:///home/kaufmannr/git/greenhopper/kafkalyzer/lib/src/ui/main_layout.dart) mit `NavigationRail` (Explorer, Consumer Lag, Scripts, Settings).
    - [`ExplorerView`](file:///home/kaufmannr/git/greenhopper/kafkalyzer/lib/src/features/explorer/presentation/explorer_view.dart) mit 360 px Cluster- & Topic-Sidebar sowie Tab-Steuerung für geöffnete Topics.
    - [`TopicDetailView`](file:///home/kaufmannr/git/greenhopper/kafkalyzer/lib/src/features/topic/topic_detail_view.dart) mit Stream-Steuerung, Avro-Schema-Dialog und [`MessagesView`](file:///home/kaufmannr/git/greenhopper/kafkalyzer/lib/src/ui/messages/messages_view.dart).
    - [`ScriptRunDetailsView`](file:///home/kaufmannr/git/greenhopper/kafkalyzer/lib/src/features/scripting/presentation/widgets/script_history/script_run_details_view.dart) für Testskripte.
- **Feedback & Empfehlung:**
  - Der 3-Zonen-Cockpit-Ansatz sollte **nicht** als Ersatz für `MainLayout` oder `ExplorerView` gebaut werden, sondern direkt in **[`MessagesView`](file:///home/kaufmannr/git/greenhopper/kafkalyzer/lib/src/ui/messages/messages_view.dart)** implementiert werden!
  - `MessagesView` ist bereits die gemeinsame Komponente für Tabelle, Timeline und Diff. Wenn `MessagesView` das Split-Layout (Master-Stream oben/links, Inspector unten/rechts) kapselt:
    - Profitieren **sowohl Topic-Live-Streaming** als auch **Skript-Ausführungen** automatisch von derselben konsistenten UX.
    - Bleiben die Cluster-Navigation, Consumer-Lag-Monitore und Skript-Verwaltung vollkommen intakt.

#### 2. Payload-Datenmodell & Performance: Isolate-Parsing vs. Synchrones In-Memory-JSON
- **Konzeptvorschlag (Kapitel 3, 4, 8):** Geht im Codebeispiel davon aus, dass `KafkaMessageItem.payload` bereits als fertige `Map<String, dynamic>` im Speicher liegt.
- **Codebase-Istzustand:**
  - In Kafkalyzer ([`KafkaMessage`](file:///home/kaufmannr/git/greenhopper/kafkalyzer/lib/src/rust/api/kafka_consumer.dart)) ist `payload` ein `String?` (roher JSON-Text, Tombstone `null` oder Binärdaten wie `<Binary Data>: ...`).
  - Das Decodieren von JSON geschieht bewusst im Hintergrund-Isolate ([`parseJsonInIsolate`](file:///home/kaufmannr/git/greenhopper/kafkalyzer/lib/src/utils/payload_processing_isolate.dart)), um bei Streams mit tausenden Nachrichten den Flutter-UI-Thread nicht zu blockieren.
  - In der Tabelle ([`MessagesTableView`](file:///home/kaufmannr/git/greenhopper/kafkalyzer/lib/src/ui/messages/views/messages_table_view.dart)) wird die Vorschau per [`TextPreviewUtils.getPayloadPreview`](file:///home/kaufmannr/git/greenhopper/kafkalyzer/lib/src/ui/text_preview_utils.dart) aus dem Rohstring abgeschnitten (max. 300 Zeichen).
- **Feedback & Empfehlung:**
  - **Master-Tabelle:** Niemals alle gestreamten Nachrichten auf dem UI-Thread synchron zu Maps parsen. Für Smart Badges in Tabellenzellen oder projizierte Spalten empfiehlt sich:
    - Asynchrones Vor-Extrahieren relevanter Felder im Worker-Isolate während des Streamings / Row-Caching in `_TableRowData`.
    - Oder Nutzung der bestehenden [`ExtractionUtils`](file:///home/kaufmannr/git/greenhopper/kafkalyzer/lib/src/features/scripting/domain/extraction_utils.dart) für gezielte Pfad-Extraktion.
  - **Live Inspector:** Da hier immer nur **genau eine Nachricht** (die aktiv ausgewählte) inspiziert wird, ist das Isolate-basierte Decodieren zu `Map<String, dynamic>` extrem schnell und verursacht keinerlei Frame-Drops.

#### 3. Tree-View-Implementierung: `JsonCardViewer` droppen zugunsten eines virtualisierten `SmartVirtualJsonTree`
- **Konzeptvorschlag (Kapitel 4, 6):** Skizziert einen rekursiven `SmartNodeViewer` auf Basis von `ExpansionTile`.
- **Analyse des aktuellen `JsonCardViewer` ([`lib/src/ui/json_card_viewer.dart`](file:///home/kaufmannr/git/greenhopper/kafkalyzer/lib/src/ui/json_card_viewer.dart)) & Screenshot-Befund:**
  - Der Entschluss, den **`JsonCardViewer` komplett fallen zu lassen, ist technisch wie ergonomisch 100 % richtig und dringend geboten**. Das reale Nutzungsbild (siehe Screenshot `analytics.tramon.kennzeichen.meilensteinPlanStatus.v4`) führt die Schwächen drastisch vor Augen:
    1. **Katastrophale Platzverschwendung & schlechte Lesbarkeit (Card-in-Card-Hölle):**
       - Der Masonry-Ansatz teilt den Screen ab 1200 px in 3 feste Spalten. Wenn eine Payload jedoch aus einem dominanten Haupt-Array (`fahrzeugMeilensteine`) besteht, landet dieses in Spalte 1 (links, ~30 % der Breite). **Über 70 % der horizontalen Bildschirmfläche bleiben komplett ungenutzter Weißraum!**
       - Verschachtelte Sub-Objekte (`transportMeilensteine[0]`) werden in Spalte 1 immer weiter eingerückt und mit Box-in-Box-Bordern versehen. Die Textfelder werden auf winzige Breiten zusammengequetscht, während der Nutzer endlos vertikal scrollen muss.
    2. **Massiver Performance-Flaschenhals (Keine Virtualisierung):**
       - `JsonCardViewer` instanziiert die gesamte JSON-Struktur synchron in einem `SingleChildScrollView`.
       - Bei echten Logistik-Payloads mit hunderten Meilensteinen oder Positionen werden auf einen Schlag **tausende Widgets** (`Container`, `BoxDecoration`, `Wrap`, `Column`, `Row`) auf dem UI-Thread gerendert und berechnet. Das führt zu spürbarem Ruckeln und sekundenlangen Einfrierern beim Öffnen.
       - Erschwerend kommt hinzu: [`JsonOrStringViewer`](file:///home/kaufmannr/git/greenhopper/kafkalyzer/lib/src/ui/json_or_string_viewer.dart#L245) setzt aktuell standardmäßig `_viewMode = 2` (Cards) als Default-Modus! Jeder Klick auf eine Message öffnet somit unweigerlich die langsamste Ansicht.
    3. **Drittanbieter-`json_explorer` (v0.1.2) ebenfalls unzureichend:**
       - `json_explorer` virtualisiert zwar, ist aber als externes Paket starr verdrahtet: Es erlaubt weder Inline-Smart-Badges noch Context-Windowing noch Pfad-Kompaktierung.
- **Feedback & Ziel-Architektur: Der `SmartVirtualJsonTree`:**
  - **`JsonCardViewer` wird ersatzlos entfernt.**
  - **Neubau eines eigenen, flachen und virtualisierten Tree-Viewers (`SmartVirtualJsonTree`):**
    - **Virtualisierte Liste (`ListView.builder` oder `ScrollablePositionedList`):** Der Baum wird in eine flache Liste sichtbarer Zeilen transformiert. Unabhängig davon, ob die Payload 10 KB oder 10 MB groß ist, rendert Flutter **nur die aktuell 20–30 sichtbaren Zeilen** ($O(\text{visible})$ statt $O(\text{total})$) $\rightarrow$ **garantierte 60 FPS**.
    - **100 % horizontale Breitennutzung:** Kein starres 3-Spalten-Masonry mehr, sondern volle Breite für Keys und Werte.
    - **Indentation Flattening:** Pfade ohne Verzweigung werden komprimiert:
      `▼ fahrzeugMeilensteine[0] . transportMeilensteine[0]`
      anstatt zwei tief verschachtelter Boxen.
    - **Smart Badges Inline:** Häufige Verbundobjekte werden auf eine Zeile als anklickbarer Chip reduziert.
    - **Sofortige Sofortmaßnahme:** In [`JsonOrStringViewer`](file:///home/kaufmannr/git/greenhopper/kafkalyzer/lib/src/ui/json_or_string_viewer.dart) den Default-Modus von `2` (Cards) auf `1` (Tree) umstellen.

#### 4. Vollständigkeit des Inspectors: Headers, Key & Metadaten beibehalten
- **Konzeptvorschlag (Kapitel 8):** Der Inspector-Entwurf fokussiert sich primär auf die Payload (Tabs: Smart Tree, Diff, Raw JSON).
- **Codebase-Istzustand:**
  - Im aktuellen [`MessageDetailsDialog`](file:///home/kaufmannr/git/greenhopper/kafkalyzer/lib/src/ui/message_details_dialog.dart) nutzen Entwickler intensiv:
    - Den separaten **Key-Viewer** (da Keys in Kafka oft Routing-Schlüssel, UUIDs oder JSON-Maps sind).
    - Den Tab **Headers** mit Anzeige und Copy-Möglichkeit aller Kafka-Header (Tracing-IDs, Tenant-Flags, Content-Type).
    - Metadaten-Badges für **Partition**, **Offset** und formatierten **Timestamp** (inkl. Millisekunden).
    - Eine integrierte Volltextsuche mit Treffer-Counter (`1/12`) und Next/Prev-Navigation (`jumpToMatch`) über Key und Payload hinweg.
- **Feedback & Empfehlung:**
  - Der neue Inspector darf diese essenziellen Kafka-Funktionen nicht verlieren.
  - **Empfohlene Inspector-Struktur:**
    - **Inspector-Header:** Message-Key, Partition, Offset, Timestamp (mit Schnellkopier-Icon) sowie Docking-Steuerung (Bottom / Right / Fullscreen / Close).
    - **Reiter:**
      1. `Smart Tree`: Virtualisierter Baum mit Smart Badges & Context Windowing (ersetzt Cards & `json_explorer`).
      2. `Key & Headers`: Strukturierte Darstellung des Keys und aller Kafka-Header mit Anzahl-Badge.
      3. `Diff (Delta)`: Vergleich zum logischen Vorgänger desselben Keys.
      4. `Raw JSON`: Unverändertes JSON für schnellen Gesamtexport.

#### 5. Diff-Heuristik: Chronologischer Vorgänger vs. Key-basierter Vorgänger
- **Konzeptvorschlag (Kapitel 8):** Verwendet im Codebeispiel schlicht `messages[selectedIndex - 1]`.
- **Codebase-Istzustand:**
  - In einem echten Kafka-Topic mit mehreren Entitäten (z. B. verschiedenen Fahrzeugen, Aufträgen oder Sendungen) ist die physisch vorherige Nachricht fast immer ein *anderer* Geschäftsvorfall. Ein Diff zu `selectedIndex - 1` würde fast alle Felder als geändert anzeigen (rot/grünes Rauschen).
  - Die bestehende [`MessagesDiffView`](file:///home/kaufmannr/git/greenhopper/kafkalyzer/lib/src/ui/messages/views/messages_diff_view.dart) löst dies bereits vorbildlich: Sie gruppiert nach Composite Key `_getCompositeKey(msg) = '${msg.topic}/${msg.key ?? "null"}'` und sucht den letzten chronologischen Stand **desselben Schlüssels**!
- **Feedback & Empfehlung:**
  - Der Inspector-Tab "Diff" muss exakt diese Key-basierte Vorgänger-Suche übernehmen.
  - Das Delta zeigt dann die echte Mutation des identischen Aggregats (z. B. Statusänderung von `OFFEN` auf `IN_BEARBEITUNG`).
  - Existiert kein Vorgänger mit demselben Key: Hinweis *"Initialer Status für diesen Key"* anzeigen, mit optionalem Umschalter *"Vergleich mit physischem Vorgänger (Offset - 1)"*.

#### 6. Tastatur- und Scroll-Synchronisation mit `two_dimensional_scrollables`
- **Codebase-Istzustand:**
  - [`MessagesTableView`](file:///home/kaufmannr/git/greenhopper/kafkalyzer/lib/src/ui/messages/views/messages_table_view.dart) nutzt `package:two_dimensional_scrollables` (`TableView.builder`) mit fixen Zeilenhöhen (44 px) und virtuellem Scrollen.
- **Feedback & Empfehlung:**
  - Die Tastatursteuerung (`↑`/`↓`, `J`/`K`) lässt sich hervorragend integrieren:
    - Der aktuell selektierte Zeilenindex wird im Zustand von `MessagesView` gehalten.
    - Die selektierte Zeile erhält einen visuellen Fokus-Indikator (`selectedRowColor`).
    - Wandert der Fokus per Taste aus dem sichtbaren Bereich, scrollt der `ScrollController` des `TableView` die Zeile automatisch ins Bild.

#### 7. Platzmanagement auf Laptops: Sidebar-Collapse in `ExplorerView`
- **Codebase-Istzustand:**
  - In [`ExplorerView`](file:///home/kaufmannr/git/greenhopper/kafkalyzer/lib/src/features/explorer/presentation/explorer_view.dart) ist die linke Sidebar für Cluster und Topics fest auf `SizedBox(width: 360)` gesetzt.
  - Zusammen mit dem `NavigationRail` (72 px) gehen standardmäßig 432 px verloren.
- **Feedback & Empfehlung:**
  - Das in Kapitel 9 vorgeschlagene **Bottom-Docking** ist exakt die richtige Antwort auf dieses Setup, da die Master-Tabelle ihre volle Breite behält.
  - Als zusätzliche Ergonomie-Maßnahme sollte die 360 px Sidebar in `ExplorerView` per Toggle-Button (oder automatisch beim Starten eines Streams) auf eine schmale 48 px Icon-Rail einklappbar sein.

---

### 10.3 Konkrete, phasenbasierte Einführungs-Roadmap

Um das Konzept ohne Unterbrechung des laufenden Betriebs und ohne Regressionen in Kafkalyzer einzuführen, empfiehlt sich folgende Reihenfolge:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ PHASE 1: Split-Screen & Inspector Shell in MessagesView                     │
│ • MessageDetailsDialog durch andockbaren Inspector (Bottom & Right) ersetzen│
│ • Header, Key-Viewer & Kafka-Header-Liste in Inspector übernehmen           │
│ • Nutzen: Beseitigt sofort das lästige Öffnen/Schließen von 10 Modals       │
├─────────────────────────────────────────────────────────────────────────────┤
│ PHASE 2: Tastatur-Steuerung & Streaming-Stepper                             │
│ • ArrowUp/Down & J/K Navigation synchronisiert Master & Inspector           │
│ • Stepper-Toolbar [◄ 14 / 42 ►] im Inspector (funktioniert auch im Fullscreen)│
├─────────────────────────────────────────────────────────────────────────────┤
│ PHASE 3: JsonCardViewer droppen & SmartVirtualJsonTree einführen            │
│ • JsonCardViewer komplett entfernen; JsonOrStringViewer Default auf Tree    │
│ • Flacher, virtualisierter Tree (ListView.builder) mit 60 FPS bei Groß-JSON │
│ • EntityFormatterRegistry & SmartCompositeBadges inline im Tree             │
├─────────────────────────────────────────────────────────────────────────────┤
│ PHASE 4: Context Windowing (Treffer ±1) & Flattening                        │
│ • ContextWindowCalculator für lange Objektlisten in der Payload            │
│ • Indentation Flattening (leistungen[0].transportMeilensteine[0])          │
│ • Auto-Fokus & Center-Scroll zum Suchtreffer                                │
├─────────────────────────────────────────────────────────────────────────────┤
│ PHASE 5: Field Projection & "Add to Columns"                                │
│ • Dynamische Spalten in TableView.builder via Pfad-Extraktion               │
│ • Rechtsklick auf Tree-Key -> "Als Tabellenspalte anheften"                 │
│ • Presets pro Topic in SharedPreferences speichern                          │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### 10.4 Fazit

Das vorliegende UX- und Architektur-Konzept ist fachlich exzellent ausgearbeitet und löst die Kernprobleme der aktuellen Ansichten pragmatisch und modern. 

Die Entscheidung, den unvirtualisierten **`JsonCardViewer` fallen zu lassen**, räumt eine der größten Performance- und Usability-Bremsen in Kafkalyzer auf. Zusammen mit der Verankerung in **`MessagesView`**, dem **`SmartVirtualJsonTree`**, dem **Key-/Header-Handling** und der **Key-basierten Diff-Ermittlung** erhält Kafkalyzer eine schlanke, extrem performante und ergonomische Grundlage für professionelle Kafka-Analysen.