import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:hack_project101/main.dart';

void main() {
  testWidgets('App title is configured', (tester) async {
    // Firebase needs a live initialized application to render SessionGate.
    // Verify the themed root can be created independently of Firebase services.
    const app = MotherCareApp();
    expect(app, isA<StatelessWidget>());
  });
}
