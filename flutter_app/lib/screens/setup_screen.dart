import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../theme.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int _step = 0; // 0: connect, 1: train, 2: done
  bool _loading = false;
  bool _analyzing = false;
  bool _authenticated = false;
  List<Map<String, dynamic>> _emails = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    setState(() => _loading = true);
    try {
      final s = await ApiService.getAuthStatus();
      _authenticated = s['authenticated'] == true;
      if (_authenticated) {
        _step = 1;
        await _fetchEmails();
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _connectGmail() async {
    try {
      final url = await ApiService.getLoginUrl();
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _fetchEmails() async {
    setState(() { _loading = true; _error = null; });
    try {
      final emails = await ApiService.getInbox(maxResults: 10, unreadOnly: false);
      setState(() { _emails = emails; _step = 1; });
    } catch (e) {
      setState(() => _error = 'Failed to fetch emails: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _analyzeStyle() async {
    if (_emails.isEmpty) return;
    setState(() { _analyzing = true; _error = null; });
    try {
      final samples = _emails.map((e) => {
        'subject': e['subject']?.toString() ?? '',
        'body': e['body']?.toString() ?? e['snippet']?.toString() ?? '',
      }).toList();
      await ApiService.analyzeTone(samples);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Style profile created successfully!'), backgroundColor: AppTheme.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('503') || msg.contains('Ollama')) {
        setState(() => _error = 'Ollama is not running. Open a terminal and run:\n\n  ollama serve\n\nThen try again.');
      } else {
        setState(() => _error = 'Analysis failed: $msg');
      }
    } finally {
      setState(() => _analyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Setup', style: GoogleFonts.dmMono())),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(24), children: [
              _StepBar(step: _step),
              const SizedBox(height: 32),
              if (_error != null) _ErrorBox(message: _error!),
              if (_step == 0) _ConnectStep(onConnect: _connectGmail, onCheckAgain: _checkAuth),
              if (_step == 1) _TrainStep(emails: _emails, analyzing: _analyzing, onAnalyze: _analyzeStyle, onRefetch: _fetchEmails),
            ]),
    );
  }
}

class _ConnectStep extends StatelessWidget {
  final VoidCallback onConnect, onCheckAgain;
  const _ConnectStep({required this.onConnect, required this.onCheckAgain});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Connect Gmail', style: GoogleFonts.dmMono(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrim)),
      const SizedBox(height: 8),
      Text('Sign in with your Google account so we can read your emails and learn your writing style.', style: GoogleFonts.dmMono(fontSize: 13, color: AppTheme.textSec, height: 1.6)),
      const SizedBox(height: 32),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.login_rounded),
          label: Text('Open Google Sign-In', style: GoogleFonts.dmMono(fontSize: 14, color: Colors.white)),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, padding: const EdgeInsets.symmetric(vertical: 16)),
          onPressed: onConnect,
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: onCheckAgain,
          child: Text('I already signed in — check again', style: GoogleFonts.dmMono(fontSize: 12, color: AppTheme.textMute)),
        ),
      ),
    ]);
  }
}

class _TrainStep extends StatelessWidget {
  final List<Map<String, dynamic>> emails;
  final bool analyzing;
  final VoidCallback onAnalyze, onRefetch;
  const _TrainStep({required this.emails, required this.analyzing, required this.onAnalyze, required this.onRefetch});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Train Your Style', style: GoogleFonts.dmMono(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrim)),
      const SizedBox(height: 8),
      Text('We found ${emails.length} emails. The AI will analyze them to learn your writing tone, vocabulary, and style.', style: GoogleFonts.dmMono(fontSize: 13, color: AppTheme.textSec, height: 1.6)),
      const SizedBox(height: 20),

      // Sample preview
      Text('SAMPLE EMAILS', style: GoogleFonts.dmMono(fontSize: 10, color: AppTheme.textMute, letterSpacing: 1.5)),
      const SizedBox(height: 10),
      ...emails.take(6).map((e) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
        child: Row(children: [
          const Icon(Icons.email_outlined, size: 14, color: AppTheme.textMute),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e['subject'] ?? '(no subject)', style: GoogleFonts.dmMono(fontSize: 12, color: AppTheme.textPrim, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(e['from'] ?? '', style: GoogleFonts.dmMono(fontSize: 10, color: AppTheme.textMute), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
        ]),
      )),

      if (emails.length > 6)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text('+ ${emails.length - 6} more emails included in training', style: GoogleFonts.dmMono(fontSize: 11, color: AppTheme.textMute)),
        ),

      const SizedBox(height: 20),

      if (analyzing)
        Center(child: Column(children: [
          const CircularProgressIndicator(color: AppTheme.accent),
          const SizedBox(height: 16),
          Text('Analyzing writing style...', style: GoogleFonts.dmMono(fontSize: 13, color: AppTheme.textSec)),
          const SizedBox(height: 4),
          Text('This may take a minute', style: GoogleFonts.dmMono(fontSize: 11, color: AppTheme.textMute)),
        ]))
      else
        Column(children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.auto_awesome_rounded, size: 16),
              label: Text('Analyze My Writing Style', style: GoogleFonts.dmMono(fontSize: 14, color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: onAnalyze,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 14, color: AppTheme.textMute),
              label: Text('Refresh emails', style: GoogleFonts.dmMono(fontSize: 12, color: AppTheme.textMute)),
              onPressed: onRefetch,
            ),
          ),
        ]),
    ]);
  }
}

class _StepBar extends StatelessWidget {
  final int step;
  const _StepBar({required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _StepDot(n: 1, label: 'Connect', done: step > 0, active: step == 0),
      Expanded(child: Container(height: 1, color: step > 0 ? AppTheme.green : AppTheme.border, margin: const EdgeInsets.only(bottom: 18))),
      _StepDot(n: 2, label: 'Train', done: step > 1, active: step == 1),
      Expanded(child: Container(height: 1, color: step > 1 ? AppTheme.green : AppTheme.border, margin: const EdgeInsets.only(bottom: 18))),
      _StepDot(n: 3, label: 'Done', done: step > 2, active: step == 2),
    ]);
  }
}

class _StepDot extends StatelessWidget {
  final int n;
  final String label;
  final bool done, active;
  const _StepDot({required this.n, required this.label, required this.done, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = done ? AppTheme.green : active ? AppTheme.accent : AppTheme.border;
    return Column(children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: (done || active) ? color : AppTheme.surface, shape: BoxShape.circle, border: Border.all(color: color)),
        child: Center(child: done
            ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
            : Text('$n', style: GoogleFonts.dmMono(fontSize: 12, color: active ? Colors.white : AppTheme.textMute))),
      ),
      const SizedBox(height: 4),
      Text(label, style: GoogleFonts.dmMono(fontSize: 10, color: active ? AppTheme.textPrim : AppTheme.textMute)),
    ]);
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.red.withOpacity(0.3))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.error_outline_rounded, color: AppTheme.red, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: GoogleFonts.dmMono(fontSize: 12, color: AppTheme.red))),
      ]),
    );
  }
}
