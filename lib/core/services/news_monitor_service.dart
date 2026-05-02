import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'ai_service.dart';

class NewsMonitorService {
  static const _rssUrl = 'https://news.google.com/rss/search?q=fire+OR+flood+OR+emergency+OR+accident+OR+disaster+Tamil+Nadu&hl=en-IN&gl=IN&ceid=IN:en';
  static Timer? _timer;
  static bool _isRunning = false;

  static void start() {
    if (_isRunning) return;
    _isRunning = true;
    _timer = Timer.periodic(const Duration(minutes: 10), (_) => _checkNews());
    _checkNews(); // Run immediately
  }

  static void stop() {
    _timer?.cancel();
    _isRunning = false;
  }

  static Future<void> _checkNews() async {
    try {
      final response = await http.get(Uri.parse(_rssUrl));
      if (response.statusCode != 200) return;

      final doc = XmlDocument.parse(response.body);
      final items = doc.findAllElements('item');

      for (final item in items.take(5)) {
        final title = item.findElements('title').first.innerText;
        final link = item.findElements('link').first.innerText;
        
        // Check if already processed
        final existing = await FirebaseFirestore.instance
            .collection('news_headlines')
            .where('headline', isEqualTo: title)
            .limit(1)
            .get();
        if (existing.docs.isNotEmpty) continue;

        // Parse with AI
        final parsed = await parseMediaAlert(title);
        if (parsed == null) continue;

        // Create ticket
        final needRef = FirebaseFirestore.instance.collection('needs').doc();
        await needRef.set({
          'title': parsed['title'] ?? title,
          'location': parsed['location'] ?? 'Unknown',
          'priority': parsed['priority'] ?? 3,
          'volunteersNeeded': parsed['volunteersNeeded'] ?? 5,
          'category': parsed['category'] ?? 'Other',
          'status': 'Awaiting Field Assignment',
          'source': 'news_auto',
          'newsLink': link,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Store headline to prevent duplicates
        await FirebaseFirestore.instance.collection('news_headlines').add({
          'headline': title,
          'processedAt': FieldValue.serverTimestamp(),
          'needId': needRef.id,
        });

        debugPrint('✅ Auto-created ticket from news: $title');
      }
    } catch (e) {
      debugPrint('News monitor error: $e');
    }
  }
}
