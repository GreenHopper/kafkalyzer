## 1. Setup & New Components

- [x] 1.1 Create the reusable `KpiCard` widget in `lib/src/features/consumer/presentation/widgets/kpi_card.dart`
- [x] 1.2 Implement the dashboard metric calculation utilities and getters inside `_ConsumerLagViewState`

## 2. Redesign Controls Toolbar

- [x] 2.1 Refactor `ConsumerGroupControls` with card styling and modern layout constraints
- [x] 2.2 Replace raw `DropdownButton` with the reusable global `ClusterDropdown` widget
- [x] 2.3 Align dropdowns, search field, and connection states cleanly inside the toolbar

## 3. Dashboard Integration & Empty States

- [x] 3.1 Integrate `KpiCard` metrics row at the top of `ConsumerLagView`
- [x] 3.2 Add a clean onboarding view with active cluster connection check and illustrations
- [x] 3.3 Ensure the table columns for group list and partition detail tables have aligned widths and styling
- [x] 3.4 Display a connection loading screen when `activeController.isConnecting` is true

## 4. Verification & Testing

- [x] 4.1 Verify that the codebase builds successfully and passes Dart formatting
- [x] 4.2 Validate visually that the cluster state transitions, metrics, and search filtering work as expected
