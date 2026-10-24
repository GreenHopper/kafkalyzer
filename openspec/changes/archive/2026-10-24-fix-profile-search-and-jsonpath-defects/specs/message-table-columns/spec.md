# Spec Delta

## MODIFIED Requirements

### Requirement: Dynamic Projected Columns in Message Table View
The message table view SHALL support user-defined dynamic projected columns extracted from JSON message payloads using the canonical field-path language of the `json-path-resolution` capability (nested object dot-notation, array indices, `$.`-prefixed paths and slash-prefixed JSON Pointer, e.g. `customer.id`, `address.city`, `leistungen[0].transportId`, `$.order.status`).

#### Scenario: Rendering projected column cells

- **WHEN** the message table is configured with one or more projected column paths
- **THEN** the table SHALL extract the corresponding value from each row's payload using the JSON path
- **AND** the extracted value SHALL be rendered in a dedicated column cell
- **AND** extracted cell values SHALL be cached per table row to prevent redundant JSON decoding or string traversal during scroll

#### Scenario: Accepted path notations

- **WHEN** a projected column is configured with `$.order.items[1].sku`, `order.items.1.sku`, or `/order/items/1/sku`
- **THEN** the column SHALL show the same value for each of those three configurations on a payload that contains that field

#### Scenario: Sorting and filtering projected columns

- **WHEN** a user clicks the header of a projected column
- **THEN** the table SHALL sort rows ascending or descending based on the extracted values
- **AND** when a user clicks the filter icon on a projected column header, a filter dialog SHALL open allowing substring filtering

#### Scenario: Removing a projected column

- **WHEN** a user clicks the remove action (e.g. close icon) on a projected column header
- **THEN** the projected column SHALL be removed from the active table columns
- **AND** the table layout SHALL immediately adjust to reflect the remaining columns
