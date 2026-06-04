import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _data = await ApiService.getStyleProfile();
    } catch (_) {} finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: Text('Delete Profile?', style: GoogleFonts.dmMono(color: AppTheme.textPrim)),
        content: Text('Your writing style profile will be permanently deleted.', style: GoogleFonts.dmMono(color: AppTheme.textSec, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.dmMono(color: AppTheme.textSec))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete', style: GoogleFonts.dmMono(color: AppTheme.red))),
        ],
      ),
    );
    if (ok == true) {
      await ApiService.deleteProfile();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Style Profile', style: GoogleFonts.dmMono()),
        actions: [
          if (_data != null) IconButton(icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.red), onPressed: _delete, tooltip: 'Delete profile'),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? _EmptyState()
              : _ProfileView(data: _data!),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 72, height: 72, decoration: BoxDecoration(color: AppTheme.surface, shape: BoxShape.circle, border: Border.all(color: AppTheme.border)), child: const Icon(Icons.person_outline_rounded, color: AppTheme.textMute, size: 32)),
        const SizedBox(height: 20),
        Text('No Style Profile', style: GoogleFonts.dmMono(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrim)),
        const SizedBox(height: 8),
        Text('Train your AI by analyzing emails from your inbox.', style: GoogleFonts.dmMono(fontSize: 13, color: AppTheme.textMute, height: 1.5), textAlign: TextAlign.center),
        const SizedBox(height: 28),
        ElevatedButton.icon(
          icon: const Icon(Icons.auto_awesome_rounded, size: 16),
          label: Text('Go to Setup', style: GoogleFonts.dmMono(color: Colors.white)),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
          onPressed: () => Navigator.pushNamed(context, '/setup'),
        ),
      ]),
    ));
  }
}

class _ProfileView extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ProfileView({required this.data});

  @override
  Widget build(BuildContext context) {
    final p = (data['profile'] is Map) ? Map<String, dynamic>.from(data['profile'] as Map) : <String, dynamic>{};
    final sampleCount = data['sample_count'] ?? 0;
    final summary = p['style_summary'] as String? ?? 'No summary available.';

    return ListView(padding: const EdgeInsets.all(20), children: [
      // Hero card
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppTheme.accent.withOpacity(0.15), AppTheme.purple.withOpacity(0.08)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.accent.withOpacity(0.25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.person_rounded, color: AppTheme.accent, size: 22)),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Your Writing Style', style: GoogleFonts.dmMono(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrim)),
              Text('Trained on $sampleCount emails', style: GoogleFonts.dmMono(fontSize: 11, color: AppTheme.textMute)),
            ]),
          ]),
          const SizedBox(height: 16),
          Text(summary, style: GoogleFonts.dmMono(fontSize: 12, color: AppTheme.textSec, height: 1.7)),
        ]),
      ),

      const SizedBox(height: 20),

      // Stats row
      Row(children: [
        Expanded(child: _Stat(label: 'TONE', value: p['tone'] ?? '-', color: AppTheme.accent)),
        const SizedBox(width: 10),
        Expanded(child: _Stat(label: 'WARMTH', value: p['warmth'] ?? '-', color: AppTheme.green)),
        const SizedBox(width: 10),
        Expanded(child: _Stat(label: 'FORMALITY', value: '${p['formality_score'] ?? '-'}/10', color: AppTheme.purple)),
      ]),

      const SizedBox(height: 20),

      // Detail rows
      Text('WRITING STYLE DETAILS', style: GoogleFonts.dmMono(fontSize: 10, color: AppTheme.textMute, letterSpacing: 1.5)),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
        child: Column(children: [
          _DetailRow('Sentence Style', p['sentence_style']),
          _DetailRow('Vocabulary', p['vocabulary_level']),
          _DetailRow('Response Style', p['response_style']),
          _DetailRow('Emoji Usage', p['emoji_usage'], isLast: true),
        ]),
      ),

      const SizedBox(height: 20),

      // Chips
      if (p['typical_greetings'] is List) _ChipSection('GREETINGS', List<String>.from(p['typical_greetings'] as List), AppTheme.green),
      if (p['typical_signoffs'] is List) _ChipSection('SIGN-OFFS', List<String>.from(p['typical_signoffs'] as List), AppTheme.purple),
      if (p['key_phrases'] is List) _ChipSection('KEY PHRASES', List<String>.from(p['key_phrases'] as List), AppTheme.accent),

      const SizedBox(height: 16),

      // Retrain
      OutlinedButton.icon(
        icon: const Icon(Icons.settings_rounded, size: 15),
        label: Text('Retrain Style Profile', style: GoogleFonts.dmMono(fontSize: 13)),
        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.textSec, side: const BorderSide(color: AppTheme.border), padding: const EdgeInsets.symmetric(vertical: 14)),
        onPressed: () => Navigator.pushNamed(context, '/setup'),
      ),
    ]);
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.dmMono(fontSize: 9, color: AppTheme.textMute, letterSpacing: 1.2)),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.dmMono(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final dynamic value;
  final bool isLast;
  const _DetailRow(this.label, this.value, {this.isLast = false});

  @override
  Widget build(BuildContext context) {
    if (value == null) return const SizedBox.shrink();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Text(label, style: GoogleFonts.dmMono(fontSize: 12, color: AppTheme.textMute)),
          const Spacer(),
          Text(value.toString(), style: GoogleFonts.dmMono(fontSize: 12, color: AppTheme.textPrim)),
        ]),
      ),
      if (!isLast) const Divider(height: 1, color: AppTheme.border),
    ]);
  }
}

class _ChipSection extends StatelessWidget {
  final String title;
  final List<String> items;
  final Color color;
  const _ChipSection(this.title, this.items, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.dmMono(fontSize: 10, color: AppTheme.textMute, letterSpacing: 1.5)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: items.map((v) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))),
          child: Text(v, style: GoogleFonts.dmMono(fontSize: 11, color: color)),
        )).toList()),
      ]),
    );
  }
}
