import 'package:flutter_test/flutter_test.dart';
import 'package:hack_project101/services.dart';
import 'package:hack_project101/language.dart';

void main() {
  test('predefined urgent symptom goes to urgent queue without AI', () {
    final codes = SymptomRules.localCodes('', ['Heavy bleeding']);
    final result = SymptomRules.fromCodes(codes, aiUsed: false, status: 'selected_only');
    expect(result.urgent, true);
    expect(result.matchedWarningSigns, contains('heavy_bleeding'));
  });
  test('routine symptom does not match a hardcoded warning sign', () {
    final codes = SymptomRules.localCodes('', ['Fatigue']);
    final result = SymptomRules.fromCodes(codes, aiUsed: false, status: 'selected_only');
    expect(result.urgent, false);
  });
  test('Urdu severe headache keyword gets a warning flag', () {
    final codes = SymptomRules.localCodes('میرے سر میں شدید درد ہے', []);
    expect(codes, contains('severe_headache'));
  });
  test('language labels follow user preference', () {
    appLanguage.value = 'Urdu';
    expect(tr('Glucose monitoring', 'شوگر کی نگرانی'), 'شوگر کی نگرانی');
    appLanguage.value = 'English';
  });
}
