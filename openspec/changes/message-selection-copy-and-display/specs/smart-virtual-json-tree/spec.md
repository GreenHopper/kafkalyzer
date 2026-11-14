## ADDED Requirements

### Requirement: Copy Field Path from Tree Row
A secondary click on a tree row SHALL open a context menu with "Copy value" and "Copy field path" (plus "Pin as column" where pinning is available). The copied path SHALL use the canonical field-path language, without internal tree prefixes, and SHALL resolve to the same field when used as a projected column or filter path.

#### Scenario: Copy a nested path
- **WHEN** the user chooses "Copy field path" on the `transportId` row inside the first entry of `leistungen`
- **THEN** the clipboard SHALL contain `leistungen[0].transportId`

#### Scenario: Key that cannot be written in dot form
- **WHEN** the user copies the path of a field whose key contains `.`, `[`, `]` or `/`, such as the key `a.b` inside `meta`
- **THEN** the clipboard SHALL contain the JSON Pointer form `/meta/a.b`, with `/` and `~` in keys escaped as `~1` and `~0`

#### Scenario: Path of a compound breadcrumb row
- **WHEN** the user copies the path of a row that shows a flattened single-child chain such as `order.customer`
- **THEN** the clipboard SHALL contain the full path of the innermost node of that chain

#### Scenario: Path round-trips through a projected column
- **WHEN** a copied path is added as a projected table column
- **THEN** the column SHALL show the value of the row the path was copied from

#### Scenario: Root row has no path
- **WHEN** the user opens the context menu on the root row of the tree
- **THEN** "Copy field path" SHALL NOT be offered
