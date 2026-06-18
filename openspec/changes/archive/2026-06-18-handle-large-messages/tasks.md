## 1. Background Processing Isolate (Dart)

- [x] 1.1 Create utility functions for heavy parsing operations (e.g., JSON decoding and pretty-printing) that can be run in Dart isolates using `compute`.
- [x] 1.2 Create utility functions for hex generation that can also be run in an isolate using `compute`.

## 2. Viewer UI Updates

- [x] 2.1 Update `JsonOrStringViewer` to accept data asynchronously or trigger isolate processing upon receiving raw payload.
- [x] 2.2 Add a loading state (`CircularProgressIndicator`) in `JsonOrStringViewer` while isolate parsing is active.
- [x] 2.3 Update `HexViewer` similarly to process hex formatting asynchronously and display a loading spinner.

## 3. Truncation and Safety Limits

- [x] 3.1 Implement a safe character limit (e.g., 500,000 chars) for `JsonOrStringViewer` and `HexViewer` output to prevent UI lag.
- [x] 3.2 Display a warning or banner when output is truncated, confirming the user can still use "Copy" or "Save to File" to extract the full data.

## 4. Testing and Verification

- [x] 4.1 Update existing UI tests to mock or await the new asynchronous parsing logic.
- [x] 4.2 Run `flutter test` to ensure no regressions in viewer components.
- [x] 4.3 Run `dart format` on the modified files.
