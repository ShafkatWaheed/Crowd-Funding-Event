// Entry point — all tests are organized in subdirectories:
//   test/models/     — Model unit tests (~30 tests)
//   test/providers/  — Provider unit tests (~25 tests)
//   test/screens/    — Widget/screen tests (~87 tests)
//
// Run all: flutter test
// Run specific: flutter test test/models/
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sanity check', () {
    expect(1 + 1, 2);
  });
}
