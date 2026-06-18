import re

def fix_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Add awaitIsolates helper if missing
    helper = """
Future<void> awaitIsolates(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
  await tester.pump();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
  await tester.pump();
}
"""
    if "Future<void> awaitIsolates" not in content:
        content = content.replace("void main() {", helper + "\nvoid main() {")

    # Replace existing pumpAndSettle
    content = content.replace("await tester.pumpAndSettle();", "await awaitIsolates(tester);")

    # After pumpWidget, insert awaitIsolates if not followed by tap or awaitIsolates
    new_content = ""
    idx = 0
    while True:
        pos = content.find("await tester.pumpWidget(", idx)
        if pos == -1:
            new_content += content[idx:]
            break
            
        new_content += content[idx:pos]
        idx = pos
        
        paren_count = 0
        in_string = False
        string_char = None
        end_pos = -1
        
        for i in range(pos, len(content)):
            char = content[i]
            if in_string:
                if char == string_char and content[i-1] != '\\':
                    in_string = False
                continue
            if char in ["'", '"']:
                in_string = True
                string_char = char
                continue
            if char == '(':
                paren_count += 1
            elif char == ')':
                paren_count -= 1
                if paren_count == 0:
                    if i + 1 < len(content) and content[i+1] == ';':
                        end_pos = i + 2
                        break
        
        if end_pos != -1:
            new_content += content[pos:end_pos]
            idx = end_pos
            next_code = content[end_pos:end_pos+100]
            if "await awaitIsolates" not in next_code and "await tester.tap" not in next_code:
                new_content += "\n      await awaitIsolates(tester);\n"
        else:
            new_content += content[pos:pos+24]
            idx = pos + 24

    # Fix tap copy button
    new_content = new_content.replace(
        "await tester.tap(copyButton);\n      await tester.pump();",
        "await tester.tap(copyButton);\n      await awaitIsolates(tester);"
    )

    with open(filepath, 'w') as f:
        f.write(new_content)

fix_file('test/src/ui/json_or_string_viewer_test.dart')
fix_file('test/src/ui/hex_viewer_test.dart')
print("Done")
