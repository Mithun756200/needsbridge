import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/geocoding_service.dart';
import '../../../core/services/image_service.dart';
import '../../../core/services/audit_service.dart';

class PublicReportScreen extends StatefulWidget {
  const PublicReportScreen({super.key});
  @override
  State<PublicReportScreen> createState() => _PublicReportScreenState();
}

class _PublicReportScreenState extends State<PublicReportScreen> {
  final _titleC    = TextEditingController();
  final _locationC = TextEditingController();
  final _contactC  = TextEditingController();
  bool _isSubmitting = false;
  XFile? _image;

  Future<void> _detectLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return;
      }
      final pos = await Geolocator.getCurrentPosition();
      setState(() => _locationC.text = '${pos.latitude}, ${pos.longitude}');
    } catch (_) {}
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 60, maxWidth: 1024);
    if (picked != null) setState(() => _image = picked);
  }

  bool _isCoords(String s) {
    final p = s.split(',');
    return p.length == 2 &&
        double.tryParse(p[0].trim()) != null &&
        double.tryParse(p[1].trim()) != null;
  }

  Future<void> _submit() async {
    if (_titleC.text.trim().isEmpty || _locationC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please describe the issue and provide a location.')));
      return;
    }
    setState(() => _isSubmitting = true);

    final title = _titleC.text.trim();
    final location = _locationC.text.trim();
    final contact = _contactC.text.trim();
    final imageFile = _image;

    // Run keyword scoring IMMEDIATELY before saving
    final keywordResult = keywordPriority(title);

    try {
      // ── STEP 1: Save to Firestore with keyword-based priority ────────────
      final docRef = await FirebaseFirestore.instance.collection('needs').add({
        'title': title,
        'location': location,
        'contact': contact.isEmpty ? 'Anonymous' : contact,
        'imageUrl': '',
        'priority': keywordResult.$1,
        'volunteersNeeded': keywordResult.$2,
        'category': keywordResult.$3,
        'status': 'Response',
        'reportCount': 1,
        'source': 'public',
        'aiPending': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await AuditService.log(docRef.id, 'Public report submitted — AI refining in background');

      // ── STEP 2: Show success immediately ──────────────────────────────────
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Issue reported! AI is refining priority in the background.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4)));
        _titleC.clear(); _locationC.clear(); _contactC.clear();
        setState(() { _image = null; _isSubmitting = false; });
      }

      // ── STEP 3: Run AI + Geocoding + Image upload in background ──────────
      _runBackgroundProcessing(docRef, title, location, imageFile);

    } catch (e) {
      print('Firestore error: $e'); // Debug log
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: ${e.toString().contains('PERMISSION_DENIED') ? 'Permission denied - please try again' : e.toString()}'), 
            backgroundColor: Colors.red));
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// Runs AI scoring + geocoding + image upload after the user has already
  /// seen the success message. Updates Firestore doc when done.
  Future<void> _runBackgroundProcessing(
      DocumentReference docRef, String title, String location, XFile? imageFile) async {
    try {
      String resolvedLocation = location;

      // Geocode text address with timeout
      if (!_isCoords(location)) {
        try {
          final coords = await GeocodingService.geocode(location)
              .timeout(const Duration(seconds: 10));
          if (coords != null) resolvedLocation = '${coords.$1},${coords.$2}';
        } catch (_) {}
      }

      // AI scoring + image upload in parallel
      late (int, int, String) aiResult;
      try {
        aiResult = await evaluateAIPriority(title, resolvedLocation)
            .timeout(const Duration(seconds: 15));
      } catch (_) {
        aiResult = keywordPriority(title);
      }

      final imageUrlFuture = imageFile != null
          ? ImageService.upload(imageFile, folder: 'public_reports')
              .timeout(const Duration(seconds: 30), onTimeout: () => null)
              .catchError((_) => null as String?)
          : Future<String?>.value(null);

      final imageUrl = await imageUrlFuture;

      // ── Duplicate Merging Logic ───────────────────────────────────────────
      final activeQuery = await FirebaseFirestore.instance.collection('needs').get();
      
      String? duplicateId;
      for (final doc in activeQuery.docs) {
        if (doc.id == docRef.id) continue;
        final data = doc.data();
        if (data['status'] == 'Resolved') continue;

        final existingLoc = (data['location'] as String? ?? '').toLowerCase();
        final existingTitle = (data['title'] as String? ?? '').toLowerCase();
        if ((existingLoc.isNotEmpty && existingLoc == resolvedLocation.toLowerCase()) ||
            (existingTitle.isNotEmpty && existingTitle == title.toLowerCase())) {
          duplicateId = doc.id;
          break;
        }
      }

      if (duplicateId != null) {
        // Increment report count on existing issue and delete this duplicate
        await FirebaseFirestore.instance.collection('needs').doc(duplicateId)
            .update({'reportCount': FieldValue.increment(1)});
        await AuditService.log(duplicateId, 'Duplicate report merged. Total reports incremented.');
        await docRef.delete();
        return;
      }

      await docRef.update({
        'location': resolvedLocation,
        'priority': aiResult.$1,
        'volunteersNeeded': aiResult.$2,
        'category': aiResult.$3,
        'imageUrl': imageUrl,
        'aiPending': false,
      });

      await AuditService.log(docRef.id,
          'AI scoring complete — Category: ${aiResult.$3}, Priority: ${aiResult.$1}, Volunteers: ${aiResult.$2}');

    } catch (_) {
      // Background failure — document still exists with default priority
      await docRef.update({'aiPending': false}).catchError((_) {});
    }
  }

  @override
  void dispose() { _titleC.dispose(); _locationC.dispose(); _contactC.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report a Community Issue'),
        actions: [
          TextButton(
            onPressed: () => context.go('/login'),
            child: Text('Staff Login', style: TextStyle(color: cs.primary)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.secondary.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.secondary.withAlpha(60)),
            ),
            child: const Row(children: [
              Icon(Icons.campaign_rounded, size: 28),
              SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Community Issue Portal',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  SizedBox(height: 4),
                  Text('Submit instantly — AI scores priority automatically.\nOur team is notified in real-time.',
                      style: TextStyle(fontSize: 12, height: 1.5)),
                ],
              )),
            ]),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleC,
            maxLines: 3, minLines: 1,
            decoration: const InputDecoration(
                labelText: 'Describe the issue *',
                hintText: 'e.g. Fire near school, flood blocking road...',
                prefixIcon: Icon(Icons.edit_note_rounded)),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _locationC,
            decoration: InputDecoration(
              labelText: 'Location * (address or GPS)',
              prefixIcon: const Icon(Icons.location_on_rounded),
              suffixIcon: IconButton(
                  icon: const Icon(Icons.my_location_rounded),
                  onPressed: _detectLocation,
                  tooltip: 'Use my GPS location'),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _contactC,
            decoration: const InputDecoration(
                labelText: 'Your contact info (optional)',
                prefixIcon: Icon(Icons.phone_rounded)),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _isSubmitting ? null : _pickImage,
            icon: Icon(
                _image == null ? Icons.add_photo_alternate_rounded : Icons.check_circle_rounded,
                color: _image != null ? Colors.green : null),
            label: Text(_image == null
                ? 'Attach Photo (optional)'
                : '✓ Photo: ${_image!.name}'),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(
                backgroundColor: cs.secondary,
                padding: const EdgeInsets.symmetric(vertical: 16)),
            child: _isSubmitting
                ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                    SizedBox(width: 12),
                    Text('Submitting…'),
                  ])
                : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.send_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Submit Report',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ]),
          ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.auto_awesome_rounded, size: 14,
                color: isDark ? Colors.white38 : Colors.black38),
            const SizedBox(width: 6),
            Text('Powered by Gemini AI — Priority scored automatically',
                style: TextStyle(fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black38)),
          ]),
        ]),
      ),
    );
  }
}
