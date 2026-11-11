import 'package:flutter/foundation.dart';

/// Session-level language selection, available before sign-in.
final ValueNotifier<String> appLanguage = ValueNotifier<String>('English');
bool languageChosenBeforeLogin = false;
String? languageHydratedForUid;
bool get isUrdu => appLanguage.value == 'Urdu';
String tr(String english, String urdu) => isUrdu ? urdu : english;
