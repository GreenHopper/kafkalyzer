## Why

Um die Performance und Gesundheit der Datenverarbeitung im Kafka-Cluster effektiv zu überwachen, wird eine Übersicht aller Consumer und deren Lags (Verzögerung bei der Nachrichtenverarbeitung) benötigt. Dies ermöglicht es Administratoren und Entwicklern, langsame oder hängengebliebene Consumer (Bottlenecks) schnell zu identifizieren, bevor sie sich auf nachgelagerte Systeme auswirken.

## What Changes

- Implementierung einer neuen UI-View, die tabellarisch (oder visuell) alle aktiven (und ggf. inaktiven) Consumer-Gruppen des Clusters darstellt.
- Anzeige der zugehörigen Topics, Partitionen und der aktuellen Lags (Differenz zwischen Log End Offset und Current Offset) pro Consumer.
- Integration oder Erweiterung der Backend-API (Rust) zur Abfrage von Consumer-Metriken aus Kafka (Consumer Groups, Offsets).
- Hinzufügen von Navigations- oder Routing-Elementen im Frontend (Dart/Flutter), um auf diese neue Ansicht zuzugreifen.

## Capabilities

### New Capabilities
- `consumer-lag-monitoring`: Bereitstellung von Metriken und UI-Komponenten zur Überwachung von Consumer Groups und deren Lags im Kafka-Cluster.

### Modified Capabilities
- Keine

## Impact

- **Frontend (Dart/Flutter)**: Neue UI-Komponente(n) und Erweiterung der bestehenden Navigation/Routes.
- **Backend (Rust)**: Neue API-Endpunkte oder Anpassung bestehender Endpunkte zur Abfrage von Kafka Consumer Group Offsets und Lags (Kafka Admin Client/Consumer Client).
- **Abhängigkeiten**: Möglicherweise Nutzung zusätzlicher Kafka-APIs zur Statusermittlung von Consumer-Gruppen.
