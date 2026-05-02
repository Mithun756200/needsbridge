import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/theme/app_theme.dart';

class ExecutiveDashboardScreen extends ConsumerWidget {
  const ExecutiveDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needsAsync    = ref.watch(needsProvider);
    final financesAsync = ref.watch(financesProvider);
    final donorsAsync   = ref.watch(donorsProvider);
    final beneAsync     = ref.watch(beneficiariesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Executive Overview'),
        actions: [
          const ThemeToggleButton(),
          IconButton(icon: const Icon(Icons.logout_rounded),
              onPressed: () => _signOut()),
        ],
      ),
      body: needsAsync.when(
        data: (needs) {
          final total     = needs.length;
          final completed = needs.where((n) => n['status'] == 'Completed').length;
          final assigned  = needs.where((n) => n['status'] == 'Assigned').length;
          final active    = total - completed;
          final highCount = needs.where((n) => (n['priority'] as int? ?? 3) == 1 && n['status'] != 'Completed').length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // KPI Row 1
              Row(children: [
                Expanded(child: KpiCard(label: 'Total Issues', value: '$total',
                    icon: Icons.list_alt_rounded, color: NbColors.info)),
                const SizedBox(width: 12),
                Expanded(child: KpiCard(label: 'Active', value: '$active',
                    icon: Icons.warning_rounded, color: NbColors.medium)),
                const SizedBox(width: 12),
                Expanded(child: KpiCard(label: 'Completed', value: '$completed',
                    icon: Icons.check_circle_rounded, color: NbColors.low)),
              ]),
              const SizedBox(height: 12),
              // KPI Row 2
              Row(children: [
                Expanded(child: donorsAsync.when(
                  data: (d) => KpiCard(label: 'Donors', value: '${d.length}',
                      icon: Icons.favorite_rounded, color: Colors.pink),
                  loading: () => const KpiCard(label: 'Donors', value: '…', icon: Icons.favorite_rounded, color: Colors.pink),
                  error: (_,__) => const KpiCard(label: 'Donors', value: 'Err', icon: Icons.favorite_rounded, color: Colors.pink),
                )),
                const SizedBox(width: 12),
                Expanded(child: beneAsync.when(
                  data: (b) => KpiCard(label: 'Beneficiaries', value: '${b.length}',
                      icon: Icons.people_rounded, color: Colors.purple),
                  loading: () => const KpiCard(label: 'Beneficiaries', value: '…', icon: Icons.people_rounded, color: Colors.purple),
                  error: (_,__) => const KpiCard(label: 'Beneficiaries', value: 'Err', icon: Icons.people_rounded, color: Colors.purple),
                )),
                const SizedBox(width: 12),
                Expanded(child: financesAsync.when(
                  data: (f) => KpiCard(label: 'Active Grants', value: '${f.length}',
                      icon: Icons.account_balance_rounded, color: Colors.teal),
                  loading: () => const KpiCard(label: 'Active Grants', value: '…', icon: Icons.account_balance_rounded, color: Colors.teal),
                  error: (_,__) => const KpiCard(label: 'Active Grants', value: 'Err', icon: Icons.account_balance_rounded, color: Colors.teal),
                )),
              ]),
              const SizedBox(height: 20),
              // Critical alert
              if (highCount > 0) _criticalBanner(context, highCount),
              const SectionHeader('Issue Status Breakdown'),
              Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: _StatusBarChart(
                  total: total, assigned: assigned,
                  completed: completed, active: active - assigned,
                ),
              )),
              const SectionHeader('Priority Distribution'),
              Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: _PriorityDonut(needs: needs),
              )),
            ]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _criticalBanner(BuildContext context, int count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NbColors.high.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NbColors.high.withAlpha(100)),
      ),
      child: Row(children: [
        const Icon(Icons.crisis_alert_rounded, color: NbColors.high),
        const SizedBox(width: 10),
        Expanded(child: Text('$count high-priority issue${count>1?"s":""} require immediate attention!',
            style: const TextStyle(color: NbColors.high, fontWeight: FontWeight.bold))),
      ]),
    );
  }

  void _signOut() => FirebaseAuth.instance.signOut();
}

// ── Bar Chart ─────────────────────────────────────────────────────────────────
class _StatusBarChart extends StatelessWidget {
  final int total, assigned, completed, active;
  const _StatusBarChart({required this.total, required this.assigned,
      required this.completed, required this.active});

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const Center(child: Text('No data yet'));
    final bars = [
      ('Active',    active,    NbColors.medium),
      ('Assigned',  assigned,  NbColors.info),
      ('Completed', completed, NbColors.low),
    ];
    return Column(children: [
      SizedBox(height: 160,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: bars.map((b) {
            final frac = total == 0 ? 0.0 : b.$2 / total;
            return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text('${b.$2}', style: TextStyle(fontWeight: FontWeight.bold, color: b.$3)),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                width: 48,
                height: math.max(frac * 130, 4),
                decoration: BoxDecoration(
                  color: b.$3,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
              ),
            ]);
          }).toList(),
        ),
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: bars.map((b) => Text(b.$1,
              style: TextStyle(fontSize: 12,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? NbColors.darkMuted : NbColors.lightMuted))).toList()),
    ]);
  }
}

// ── Donut Chart ───────────────────────────────────────────────────────────────
class _PriorityDonut extends StatelessWidget {
  final List<Map<String, dynamic>> needs;
  const _PriorityDonut({required this.needs});

  @override
  Widget build(BuildContext context) {
    final active = needs.where((n) => n['status'] != 'Completed').toList();
    if (active.isEmpty) return const Center(child: Text('No active issues'));
    final h = active.where((n) => (n['priority'] as int? ?? 3) == 1).length;
    final m = active.where((n) => (n['priority'] as int? ?? 3) == 2).length;
    final l = active.where((n) => (n['priority'] as int? ?? 3) == 3).length;
    final total = h + m + l;
    return Row(children: [
      SizedBox(width: 140, height: 140,
        child: CustomPaint(painter: _DonutPainter(h, m, l))),
      const SizedBox(width: 24),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _DonutLegend('High', h, total, NbColors.high),
        const SizedBox(height: 8),
        _DonutLegend('Medium', m, total, NbColors.medium),
        const SizedBox(height: 8),
        _DonutLegend('Low', l, total, NbColors.low),
      ]),
    ]);
  }
}

class _DonutLegend extends StatelessWidget {
  final String label;
  final int count, total;
  final Color color;
  const _DonutLegend(this.label, this.count, this.total, this.color);

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0 : (count / total * 100).round();
    return Row(children: [
      Container(width: 12, height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 8),
      Text('$label  ', style: const TextStyle(fontSize: 13)),
      Text('$count ($pct%)',
          style: TextStyle(fontWeight: FontWeight.bold, color: color)),
    ]);
  }
}

class _DonutPainter extends CustomPainter {
  final int h, m, l;
  _DonutPainter(this.h, this.m, this.l);

  @override
  void paint(Canvas canvas, Size size) {
    final total = (h + m + l).toDouble();
    if (total == 0) return;
    final cx = size.width / 2, cy = size.height / 2;
    final r = math.min(cx, cy) - 4;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    final data = [(h / total, NbColors.high), (m / total, NbColors.medium), (l / total, NbColors.low)];
    double start = -math.pi / 2;
    for (final (frac, color) in data) {
      if (frac == 0) continue;
      final sweep = frac * 2 * math.pi;
      canvas.drawArc(rect, start, sweep, false,
          Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 24..strokeCap = StrokeCap.butt);
      start += sweep;
    }
    // centre text
    final tp = TextPainter(
      text: TextSpan(text: '${h+m+l}\nActive',
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
      textAlign: TextAlign.center, textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.h != h || old.m != m || old.l != l;
}
