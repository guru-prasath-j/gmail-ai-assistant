import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/status_chip.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _backendOk = false, _ollamaOk = false, _gmailOk = false, _profileOk = false;
  bool _loading = true;
  int _pending = 0, _sent = 0;

  @override
  void initState() { super.initState(); _refresh(); }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    _backendOk = await ApiService.checkHealth();
    if (_backendOk) {
      try { final s = await ApiService.getOllamaStatus(); _ollamaOk = s['available'] == true; } catch (_) { _ollamaOk = false; }
      try { final s = await ApiService.getAuthStatus(); _gmailOk = s['authenticated'] == true; } catch (_) { _gmailOk = false; }
      try { final p = await ApiService.getStyleProfile(); _profileOk = p != null; } catch (_) { _profileOk = false; }
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gmail AI'), actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _refresh)]),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(20), children: [
              Text('SYSTEM STATUS', style: GoogleFonts.dmMono(fontSize: 10, color: AppTheme.textMute, letterSpacing: 1.5)),
              const SizedBox(height: 16),
              StatusChip(label: 'Backend Server', ok: _backendOk),
              const SizedBox(height: 10),
              StatusChip(label: 'Ollama LLM', ok: _ollamaOk),
              const SizedBox(height: 10),
              StatusChip(label: 'Gmail Auth', ok: _gmailOk),
              const SizedBox(height: 10),
              StatusChip(label: 'Style Profile', ok: _profileOk),
              const SizedBox(height: 32),
              if (!_gmailOk) ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent), onPressed: () async { final url = await ApiService.getLoginUrl(); }, child: Text('Connect Gmail', style: GoogleFonts.dmMono(color: Colors.white))),
              const SizedBox(height: 16),
              ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppTheme.surface), onPressed: () => Navigator.pushNamed(context, '/inbox'), child: Text('Open Inbox', style: GoogleFonts.dmMono(color: AppTheme.textPrim))),
              const SizedBox(height: 8),
              ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppTheme.surface), onPressed: () => Navigator.pushNamed(context, '/replies'), child: Text('Pending Replies', style: GoogleFonts.dmMono(color: AppTheme.textPrim))),
            ]),
    );
  }
}
