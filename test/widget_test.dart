import 'package:flutter_test/flutter_test.dart';

import 'package:final_final/main.dart';

void main() {
  test('App start gate can be constructed', () {
    expect(const AppStartGate(), isA<AppStartGate>());
  });
}
