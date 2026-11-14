## ADDED Requirements

### Requirement: Copy Tree Node Value as JSON
The copy action on a tree row SHALL copy object and array nodes as valid, indented JSON of the complete subtree, independent of how far the node is expanded. Primitive nodes SHALL copy their plain value: strings without surrounding quotes, numbers and booleans in their JSON form, and null as `null`. A confirmation SHALL be shown after copying.

#### Scenario: Copying an object node
- **WHEN** the user activates the copy action on a row whose value is an object
- **THEN** the clipboard SHALL contain valid JSON that parses to the same object, including all nested fields

#### Scenario: Copying an array node
- **WHEN** the user activates the copy action on a row whose value is an array
- **THEN** the clipboard SHALL contain valid JSON that parses to the same array, including items hidden by context windowing

#### Scenario: Copying a primitive node
- **WHEN** the user activates the copy action on a row whose value is the string `abc`
- **THEN** the clipboard SHALL contain `abc` without quotes
