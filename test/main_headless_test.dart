import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/main.dart';

void main() {
  test('isHeadlessInvocation detects script and help flags', () {
    expect(isHeadlessInvocation(const []), isFalse);
    expect(isHeadlessInvocation(const ['--foo']), isFalse);
    expect(isHeadlessInvocation(const ['script', 'run']), isTrue);
    expect(isHeadlessInvocation(const ['--script', 'foo.json']), isTrue);
    expect(isHeadlessInvocation(const ['--help']), isTrue);
    expect(isHeadlessInvocation(const ['-h']), isTrue);
  });
}
