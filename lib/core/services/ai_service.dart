import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

// ─── Keyword-based local priority scorer ─────────────────────────────────────
(int priority, int volunteersNeeded, String category) keywordPriority(String title) {
  final t = title.toLowerCase();
  const highKeywords = [
    'fire','flood','drowning','collapsed','collapse','explosion','blast',
    'earthquake','tsunami','cyclone','hurricane','tornado','landslide',
    'trapped','missing','kidnap','attack','shooting','violence','riot',
    'injured','injury','dead','death','unconscious','bleeding','medical',
    'hospital','ambulance','emergency','urgent','critical','danger',
    'gas leak','toxic','poison','electrocution','electrocuted',
    'accident','crash','disaster','evacuation','stranded','rescue',
  ];
  const medKeywords = [
    'road damage','pothole','broken pipe','water pipe','sewage','sewer',
    'power outage','electricity','blackout','fallen tree','tree fallen',
    'blocked road','bridge damage','infrastructure','leak','leaking',
    'contaminated water','no water supply','no electricity','no power',
    'food shortage','hunger','starvation','drought','disease outbreak',
    'epidemic','malaria','dengue','cholera','garbage overflow','shortage',
    'broken','damaged','destroyed','repair',
  ];
  String cat = 'Other';
  if (t.contains('fire')) cat = 'Fire';
  else if (t.contains('flood') || t.contains('water') || t.contains('tsunami')) cat = 'Flood';
  else if (t.contains('medical') || t.contains('injured') || t.contains('dead')) cat = 'Medical';
  else if (t.contains('road') || t.contains('bridge') || t.contains('infrastructure')) cat = 'Infrastructure';

  for (final kw in highKeywords) {
    if (t.contains(kw)) {
      final vols = (kw=='fire'||kw=='flood'||kw=='collapsed'||kw=='disaster'||kw=='evacuation') ? 20 : 10;
      return (1, vols, cat);
    }
  }
  for (final kw in medKeywords) {
    if (t.contains(kw)) return (2, 5, cat);
  }
  return (3, 2, cat);
}

// ─── Gemini AI priority evaluator ────────────────────────────────────────────
Future<(int priority, int volunteersNeeded, String category)> evaluateAIPriority(
  String title, String? location) async {
  // This key is loaded from secrets.json during the build process.
  // See the --dart-define-from-file flag in the build command.
  const apiKey = String.fromEnvironment('GEMINI_FLUTTER_API_KEY');
  final localResult = keywordPriority(title);
  try {
    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
    );
    final prompt = '''
You are a strict NGO emergency triage coordinator.
RETURN EXACTLY: {"priority": <int>, "volunteersNeeded": <int>, "category": "<string>"}
Priority: 1=HIGH (life risk, disaster, fire, flood, collapse, injury)
          2=MEDIUM (infrastructure, power, water, disease, shortage)
          3=LOW (routine, cosmetic, minor)
Category Options: "Fire", "Flood", "Medical", "Infrastructure", "Other"
Do NOT default to 3 unless truly routine.
Title: "$title" | Location: ${location ?? 'Unknown'}
''';
    final response = await model.generateContent([Content.text(prompt)]);
    final cleaned = (response.text ?? '')
        .replaceAll(RegExp(r'```json', caseSensitive: false), '')
        .replaceAll('```', '').trim();
    final data = jsonDecode(cleaned) as Map<String, dynamic>;
    final aiP = (data['priority'] as num?)?.toInt();
    final aiV = (data['volunteersNeeded'] as num?)?.toInt();
    final aiC = data['category'] as String? ?? localResult.$3;
    if (aiP == null || aiP < 1 || aiP > 3) return localResult;
    // Use AI priority directly if valid, don't downgrade with math.min
    return (aiP, aiV ?? localResult.$2, aiC);
  } catch (e) {
    debugPrint('Gemini error: $e');
    return localResult;
  }
}

// ─── Media Alert Parser ────────────────────────────────────────────────────────
Future<Map<String, dynamic>?> parseMediaAlert(String headline) async {
  // This key is loaded from secrets.json during the build process.
  // See the --dart-define-from-file flag in the build command.
  const apiKey = String.fromEnvironment('GEMINI_FLUTTER_API_KEY');
  try {
    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
    );
    final prompt = '''
You are parsing raw news headlines into an NGO emergency response ticket.
Extract the relevant details and estimate needs.
Headline: "$headline"
RETURN EXACTLY: {"title": "<short description>", "location": "<extracted location or Unknown>", "priority": <1, 2 or 3>, "volunteersNeeded": <int>, "category": "<Fire|Flood|Medical|Infrastructure|Other>"}
''';
    final response = await model.generateContent([Content.text(prompt)]);
    final cleaned = (response.text ?? '')
        .replaceAll(RegExp(r'```json', caseSensitive: false), '')
        .replaceAll('```', '').trim();
    return jsonDecode(cleaned) as Map<String, dynamic>;
  } catch (e) {
    debugPrint('Media alert parse error: $e');
    return null;
  }
}

// Simulate volunteer auto-assignment (replaced by real DB in management screen)
String simulateAutoAssignment(int needed, String location) {
  const v = ['Alice Smith','Bob Jones','Charlie Brown','Diana Prince','Evan Wright','Fiona Gallagher'];
  return v.take(needed.clamp(1, v.length)).join(', ');
}
