# Design

## Context

The scripting UI in Kafkalyzer enables users to manage and execute multi-step automated workflows across Kafka clusters. The interface is composed of:
- `ScriptManagerView`: Manages the overall catalog, collapsible sidebar, tabs (`Run`, `Edit`, `Execution`), and script lifecycle (create, duplicate, delete).
- `ScriptRunView`: Coordinates parameter binding, target cluster selection, execution triggers, and monitoring transitions.

Currently, `ScriptRunView` renders parameter fields in an unconstrained full-width column without context about what the script actually executes, and `ScriptManagerView` deletes scripts immediately on a single click without confirmation.

## Goals / Non-Goals

**Goals:**
- Guard script deletion in `ScriptManagerView` with an explicit `AlertDialog` confirmation dialog.
- Provide real-time script catalog search/filtering in the `ScriptManagerView` sidebar header.
- Structure `ScriptRunView` into a responsive two-column workspace on desktop viewports (>= 900px):
  - Left column (max-width 560px): Parameter input form with clean visual type badges and the primary `Run Script` action situated directly underneath the inputs.
  - Right column: Read-only visual pipeline preview showing all execution steps, target topics, filter templates, and extracted variables.
- Responsive layout fallback: Automatically switch to a vertically stacked single-column layout on narrower viewports (< 900px).
- Provide complete German and English localization for all new strings and labels.

**Non-Goals:**
- Modifying the underlying execution engine (`ScriptRunner`), domain models (`Script`, `ScriptStep`, `ScriptVariable`), or persistence serialization.
- Modifying `ScriptEditor` (already modernized in a prior change) or the live execution monitor (`ScriptProgressWidget`).

## Decisions

### 1. Two-Column Layout via `LayoutBuilder`
In `ScriptRunView._buildForm()`, wrap the content in a `LayoutBuilder`:
- If `constraints.maxWidth >= 900`: Render a horizontal `Row` containing:
  - Left: `ConstrainedBox(constraints: BoxConstraints(maxWidth: 540))` containing the configuration and parameter form.
  - Right: `Expanded(child: ...)` containing the read-only pipeline preview card.
- If `constraints.maxWidth < 900`: Render a single `Column` stacking the parameter card followed by the pipeline preview card.
*Rationale*: Provides immediate visibility into both input variables and pipeline structure on desktop screens, while remaining fully scrollable and responsive on smaller windows or split-screen views.

### 2. Read-Only Visual Pipeline Preview Card
Implement a clean visual representation of `script.steps` in `ScriptRunView`:
- Renders an informative header with the total step count and title.
- For each step:
  - Step number avatar/badge and step name.
  - Target cluster and topic chips.
  - Filter expression preview (if defined) formatted with a subtle monospaced container.
  - Extracted variables indicators (e.g., `↳ Extracts: transportId`) showing data flow into downstream steps.
- If a script has no steps yet, display an empty hint guiding the user to the Edit tab.
*Rationale*: Demystifies scripts for users before they hit "Run", preventing unintended queries on production topics.

### 3. Parameter Inputs with Contextual Type Badges
Rather than embedding raw strings like `"${v.name} (${v.type.name})"` into input labels:
- Use clean, localized label text for variable names.
- Display contextual icon badges (e.g. `Icons.short_text` for string, `Icons.numbers` for numeric, `Icons.schedule` for timestamp).
- Use `TimestampPickerField` for timestamp variables and `TextField` for strings/numerics.
- Place the primary `[ ► Run Script (<N> Steps) ]` button immediately below the parameter inputs inside the card.

### 4. Deletion Guard and Filter in `ScriptManagerView`
- **Deletion Guard**:
  - Replace direct `controller.deleteScript(script.id)` calls with `_confirmDeleteScript(context, l10n, controller, script)`.
  - Display an `AlertDialog` confirming the script name and warning that the action is permanent.
- **Search / Filter Field**:
  - Add a search `TextField` with `prefixIcon: Icon(Icons.search)` and clear button in the sidebar header.
  - Maintain a local `_searchQuery` state in `ScriptManagerView` and filter `controller.scripts` where `script.name.toLowerCase().contains(_searchQuery.toLowerCase())`.

## Risks / Trade-offs

- **Very Large Script Pipelines (10+ steps)**:
  - *Risk*: A long step list could push the pipeline preview card beyond the viewport height.
  - *Mitigation*: Wrap both the parameter form and the pipeline preview inside standard vertical scrolling so the user can easily review extensive pipelines.
