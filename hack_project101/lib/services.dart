import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

final auth = FirebaseAuth.instance;
final db = FirebaseFirestore.instance;

class MotherCareService {
  static Future<void> register({required String name, required String email, required String password, required bool worker, String? phone, String? registration, String? hospital, String? cnic, String language = 'English'}) async {
    final credential = await auth.createUserWithEmailAndPassword(email: email.trim().toLowerCase(), password: password);
    final uid = credential.user!.uid;
    try {
      await db.collection('users').doc(uid).set({
        'name': name.trim(), 'email': email.trim().toLowerCase(),
        'role': worker ? 'worker_pending' : 'patient',
        'phone': phone?.trim() ?? '',
        if (worker) 'registration': registration?.trim() ?? '',
        if (worker) 'hospital': hospital?.trim() ?? '',
        if (worker) 'cnic': cnic?.trim() ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!worker) {
        await db.collection('patients').doc(uid).set({
          'name': name.trim(), 'createdAt': FieldValue.serverTimestamp(),
          'assignedWorkerId': '', 'pregnancyWeeks': 0,
          'hasGdm': false, 'language': language, 'phone': phone?.trim() ?? '',
        });
      }
    } catch (_) {
      // Do not silently mask a partial signup; a privileged operator can clean it up.
      rethrow;
    }
  }

  static Future<void> savePatientProfile(String uid, {required int weeks, required bool gdm, required String language, required String phone, required String emergencyContact}) =>
      db.collection('patients').doc(uid).update({
        'pregnancyWeeks': weeks, 'hasGdm': gdm, 'language': language,
        'phone': phone.trim(), 'emergencyContact': emergencyContact.trim(),
      });

  static Future<void> saveReading({required String patientId, required double value, required String unit, required String type, Uint8List? photoBytes, String? mime}) async {
    final ref = db.collection('patients').doc(patientId).collection('readings').doc();
    String? path;
    if (photoBytes != null) {
      path = 'patients/$patientId/glucose/${ref.id}.jpg';
      await FirebaseStorage.instance.ref(path).putData(photoBytes, SettableMetadata(contentType: mime ?? 'image/jpeg'));
    }
    await ref.set({
      'patientId': patientId, 'value': value, 'unit': unit, 'type': type,
      'photoPath': path, 'confirmed': true, 'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// A patient cannot set urgency. This function derives it from the selected
  /// warning signs and normalized symptoms produced by the rules engine.
  static Future<void> saveSymptom({
    required String patientId,
    required String description,
    required List<String> selected,
    required SymptomAssessment assessment,
    required String aiSummary,
    required String language,
  }) async {
    final patient = await db.collection('patients').doc(patientId).get();
    final workerId = patient.data()?['assignedWorkerId'] as String? ?? '';
    await db.collection('patients').doc(patientId).collection('reports').add({
      'patientId': patientId,
      'assignedWorkerId': workerId,
      'description': description.trim(),
      'language': language,
      'symptoms': selected,
      'normalizedSymptoms': assessment.codes,
      'matchedWarningSigns': assessment.matchedWarningSigns,
      'aiSummary': aiSummary,
      'aiUsed': assessment.aiUsed,
      'urgency': assessment.urgent ? 'urgent' : 'needs_review',
      'triageStatus': assessment.urgent ? 'urgent_care' : 'routine_review',
      'processingStatus': assessment.processingStatus,
      'status': 'new',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static const criticalSymptoms = [
    'Heavy bleeding', 'Seizure or fainting', 'Severe headache or vision changes',
    'Chest pain or difficulty breathing', 'Severe abdominal pain',
    'Baby moving much less than usual', 'Fluid leaking', 'High fever',
    'Sudden severe swelling',
  ];

}

class GeminiAssist {
  // Configure Firebase Console > AI Logic first. Never embed a private API key.
  static GenerativeModel get _model => FirebaseAI.googleAI().generativeModel(model: 'gemini-3.8-flash');

  static Map<String, dynamic> _parseJson(String? response) {
    if (response == null) throw const FormatException('Empty AI response');
    final start = response.indexOf('{');
    final end = response.lastIndexOf('}');
    if (start < 0 || end < start) throw const FormatException('AI did not return JSON');
    return jsonDecode(response.substring(start, end + 1)) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> readGlucose(Uint8List bytes, String mime) async {
    final result = await _model.generateContent([
      Content.multi([
        TextPart('Read ONLY the digits and measurement unit visible on this glucometer screen. Return strictly JSON: {"readable":true/false,"value":number_or_null,"unit":"mg/dL"_or_"mmol/L"_or_null}. Do not guess if unclear, do not diagnose, do not infer meal timing.'),
        InlineDataPart(mime, bytes),
      ]),
    ]);
    final data = _parseJson(result.text);
    if (data['readable'] != true || data['value'] is! num || !['mg/dL', 'mmol/L'].contains(data['unit'])) {
      throw const FormatException('Image unclear. Please enter the reading manually.');
    }
    return data;
  }

  static Future<Set<String>> extractSymptoms(String description) async {
    final result = await _model.generateContent([
      Content.text('Extract symptoms semantically from this pregnant patient statement. '
          'Understand English and Urdu, including synonyms, negations and uncertainty. '
          'Return ONLY a JSON object {"symptom_codes":["code"]}. '
          'Use ONLY these code values: ${SymptomRules.allCodes.join(", ")}. '
          'For example: severe headache and blurred vision => ["severe_headache","vision_changes"]. '
          'Do not mark denied symptoms as present. Do not diagnose or decide urgency. '
          'If unclear return ["other"]. Statement: $description'),
    ]);
    final data = _parseJson(result.text);
    final raw = data['symptom_codes'];
    if (raw is! List) throw const FormatException('Invalid symptom list');
    return raw.whereType<String>().where(SymptomRules.allCodes.contains).toSet();
  }

  static Future<String> summarizeSymptoms(String description, List<String> selections) async {
    final result = await _model.generateContent([
      Content.text('Rewrite this pregnancy symptom report in simple, neutral English for a healthcare worker. Preserve all symptoms and uncertainty, do not invent facts, diagnose, classify urgency, give medical advice, or reassure. Max 65 words. Selected symptoms: ${selections.join(', ')}. Patient words: $description'),
    ]);
    return (result.text ?? '').trim();
  }
}


/// Controlled vocabulary: Gemini may select these codes, but may not invent
/// urgency levels or create new clinical rules.
class SymptomAssessment {
  final List<String> codes;
  final List<String> matchedWarningSigns;
  final bool aiUsed;
  final String processingStatus;
  bool get urgent => matchedWarningSigns.isNotEmpty;
  const SymptomAssessment({required this.codes, required this.matchedWarningSigns,
    required this.aiUsed, required this.processingStatus});
}

class SymptomRules {
  // Demonstration warning-sign vocabulary based on CDC maternal warning signs.
  // NOT a clinically validated triage protocol. Needs clinical review before
  // deployment for real patients. Non-matching never implies safety.
  static const urgentCodes = <String>{
    'heavy_bleeding', 'seizure', 'fainting', 'severe_headache',
    'vision_changes', 'chest_pain', 'difficulty_breathing',
    'severe_abdominal_pain', 'reduced_fetal_movement', 'fluid_leak',
    'high_fever', 'extreme_swelling',
  };
  static const allCodes = <String>{
    ...urgentCodes, 'nausea', 'vomiting', 'fatigue', 'mild_headache',
    'mild_swelling', 'dizziness', 'other',
  };
  static const selectedCodes = <String,List<String>>{
    'Heavy bleeding': ['heavy_bleeding'],
    'Seizure or fainting': ['seizure', 'fainting'],
    'Severe headache or vision changes': ['severe_headache','vision_changes'],
    'Chest pain or difficulty breathing': ['chest_pain','difficulty_breathing'],
    'Severe abdominal pain': ['severe_abdominal_pain'],
    'Baby moving much less than usual': ['reduced_fetal_movement'],
    'Fluid leaking': ['fluid_leak'],
    'High fever': ['high_fever'],
    'Sudden severe swelling': ['extreme_swelling'],
    'Nausea or vomiting': ['nausea','vomiting'],
    'Swelling': ['mild_swelling'],
    'Fatigue': ['fatigue'],
    'Dizziness': ['dizziness'],
    'Fever': ['other'],
    'Other symptom': ['other'],
  };

  // Lightweight, conservative fallback for common wording and Urdu phrases.
  // Severe keyword matches can alert immediately without waiting for AI.
  static const localPatterns = <String,List<String>>{
    'heavy_bleeding': ['heavy bleeding','vaginal bleeding','bleeding heavily','خون بہہ','خون آ رہا'],
    'seizure': ['seizure','convulsion','دورے','دورہ پڑ'],
    'fainting': ['fainted','fainting','passed out','بے ہوش'],
    'vision_changes': ['blurred vision','blurry vision','cannot see','نظر دھندلا','دھندلا نظر','بینائی'],
    'chest_pain': ['chest pain','سینے میں درد'],
    'difficulty_breathing': ['difficulty breathing','cannot breathe','shortness of breath','سانس لینے میں مشکل','سانس نہیں'],
    'severe_abdominal_pain': ['severe abdominal pain','severe stomach pain','شدید پیٹ درد','پیٹ میں شدید درد'],
    'reduced_fetal_movement': ['baby not moving','baby moving less','reduced fetal movement','بچے کی حرکت کم','بچہ حرکت نہیں'],
    'fluid_leak': ['water broke','leaking fluid','fluid leaking','پانی بہہ رہا'],
    'extreme_swelling': ['sudden swelling of face','extreme swelling','چہرے پر شدید سوجن'],
    'high_fever': ['high fever','fever 38','fever 39','تیز بخار'],
    'severe_headache': ['severe headache','worst headache','شدید سر درد','سر میں شدید درد'],
  };

  static Set<String> localCodes(String description, Iterable<String> selections) {
    final codes = <String>{};
    for (final s in selections) { codes.addAll(selectedCodes[s] ?? const ['other']); }
    final lower = description.toLowerCase();
    for (final e in localPatterns.entries) {
      if (e.value.any((phrase) => lower.contains(phrase))) codes.add(e.key);
    }
    return codes;
  }

  static SymptomAssessment fromCodes(Set<String> codes,
      {required bool aiUsed, required String status}) {
    final filtered = codes.where(allCodes.contains).toSet();
    final matches = filtered.where(urgentCodes.contains).toList()..sort();
    return SymptomAssessment(codes: filtered.toList()..sort(),
        matchedWarningSigns: matches, aiUsed: aiUsed, processingStatus: status);
  }

  static String? lastAiError;
  static Future<SymptomAssessment> analyze(String description, List<String> selections) async {
    lastAiError = null;
    final local = localCodes(description, selections);
    if (description.trim().isEmpty) {
      return fromCodes(local, aiUsed: false, status: 'selected_only');
    }
    try {
      final ai = await GeminiAssist.extractSymptoms(description);
      local.addAll(ai);
      return fromCodes(local, aiUsed: true, status: 'ai_processed');
    } catch (error) {
      lastAiError = error.toString();
      // Never downgrade an already detected warning sign on AI failure.
      // Record the uncertainty for review and tell the user explicitly.
      return fromCodes(local, aiUsed: false, status: 'ai_unavailable_review_needed');
    }
  }
}
