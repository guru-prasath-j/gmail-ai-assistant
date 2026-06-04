import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
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
  String? _email;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    _backendOk = await ApiService.checkHealth();
    if (_backendOk) {
      try {
        final s = await ApiService.getOllamaStatus();
        _ollamaOk = s['available'] == true;
      } catch (_) {
        _ollamaOk = false;
      }
      try {
        final s = await ApiService.getAuthStatus();
        _gmailOk = s['authenticated'] == true;
        _email = s['email'] as String?;
      } catch (_) {
        _gmailOk = false;
      }
      try {
        final p = await ApiService.getStyleProfile();
        _profileOk = p != null;
      } catch (_) {
        _profileOk = false;
      }
      try {
        final replies = await ApiService.getReplies();
        _pendingCount = replies.where((r) => r['status'] == 'pending').length;
      } catch (_) {
        _pendingCount = 0;
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _connectGmail() async {
    try {
      final url = await ApiService.getLoginUrl();
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(padding: const EdgeInsets.all(24), children: [
                  // Header
                  Row(children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Gmail AI', style: GoogleFonts.dmMono(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrim)),
                      Text(_email ?? 'Auto-Reply Assistant', style: GoogleFonts.dmMono(fontSize: 12, color: AppTheme.textMute)),
                    ]),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSec),
                      onPressed: _refresh,
                    ),
                  ]),

                  const SizedBox(height: 28),

                  // Status
                  Text('SYSTEM STATUS', style: GoogleFonts.dmMono(fontSize: 10, color: AppTheme.textMute, letterSpacing: 1.5)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
                    child: Column(children: [
                      StatusChip(label: 'Backend Server', ok: _backendOk),
                      const SizedBox(height: 14),
                      StatusChip(label: 'Ollama LLM', ok: _ollamaOk),
                      const SizedBox(height: 14),
                      StatusChip(label: 'Gmail Auth', ok: _gmailOk),
                      const SizedBox(height: 14),
                      StatusChip(label: 'Style Profile', ok: _profileOk),
                    ]),
                  ),

                  const SizedBox(height: 24),

                  // Stats
                  if (_profileOk) ...[
                    Text('OVERVIEW', style: GoogleFonts.dmMono(fontSize: 10, color: AppTheme.textMute, letterSpacing: 1.5)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('PENDING REPLIES', style: GoogleFonts.dmMono(fontSize: 10, color: AppTheme.textMute, letterSpacing: 1.5)),
                        const SizedBox(height: 6),
                        Text('$_pendingCount', style: GoogleFonts.dmMono(fontSize: 36, fontWeight: FontWeight.w700, color: _pendingCount > 0 ? AppTheme.accent : AppTheme.textSec)),
                      ]),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Actions
                  Text('ACTIONS', style: GoogleFonts.dmMono(fontSize: 10, color: AppTheme.textMute, letterSpacing: 1.5)),
                  const SizedBox(height: 12),

                  if (!_gmailOk)
                    _ActionTile(icon: Icons.login_rounded, label: 'Connect Gmail', bgColor: AppTheme.accent, textColor: Colors.white, onTap: _connectGmail),

                  if (!_profileOk && _gmailOk)
                    _ActionTile(icon: Icons.auto_awesome_rounded, label: 'Setup Style Profile', bgColor: AppTheme.purple, textColor: Colors.white, onTap: () => Navigator.pushNamed(context, '/setup').then((_) => _refresh())),

                  _ActionTile(icon: Icons.inbox_rounded, label: 'Open Inbox', onTap: () => Navigator.pushNamed(context, '/inbox')),

                  if (_pendingCount > 0)
                    _ActionTile(icon: Icons.pending_actions_rounded, label: 'Pending Replies  ($_pendingCount)', bgColor: AppTheme.accent.withOpacity(0.12), textColor: AppTheme.accent, borderColor: AppTheme.accent.withOpacity(0.3), onTap: () => Navigator.pushNamed(context, '/replies').then((_) => _refresh())),

                  _ActionTile(icon: Icons.mark_email_read_rounded, label: 'All Replies', onTap: () => Navigator.pushNamed(context, '/replies').then((_) => _refresh())),

                  _ActionTile(icon: Icons.person_rounded, label: 'Style Profile', onTap: () => Navigator.pushNamed(context, '/profile')),

                  if (_gmailOk)
                    _ActionTile(icon: Icons.settings_rounded, label: 'Setup / Retrain', onTap: () => Navigator.pushNamed(context, '/setup').then((_) => _refresh())),

                  if (_gmailOk)
                    _ActionTile(icon: Icons.logout_rounded, label: 'Logout', textColor: AppTheme.red, borderColor: AppTheme.red.withOpacity(0.2), onTap: () async {
                      await ApiService.logout();
                      _refresh();
                    }),
                ]),
              ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bgColor;
  final Color textColor;
  final Color? borderColor;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    this.bgColor = AppTheme.surface,
    this.textColor = AppTheme.textPrim,
    this.borderColor = AppTheme.border,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor ?? Colors.transparent),
            ),
            child: Row(children: [
              Icon(icon, color: textColor, size: 18),
              const SizedBox(width: 12),
              Text(label, style: GoogleFonts.dmMono(fontSize: 13, color: textColor, fontWeight: FontWeight.w500)),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, color: textColor.withOpacity(0.4), size: 18),
            ]),
          ),
        ),
      ),
    );
  }
}
