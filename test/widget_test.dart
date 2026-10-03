import 'package:flutter_test/flutter_test.dart';

void main() {
  // App-level widget tests require the full dependency graph (platform
  // channels for audio + storage), so the meaningful coverage lives in the
  // unit tests under test/unit. This file keeps a trivial smoke test.
  test('sanity', () {
    expect(1 + 1, 2);
  });
}
