import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/status_chip.dart';
import '../utils/theme_rebuild_mixin.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with ThemeRebuildMixin {
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
      } catch (_) { _ollamaOk = false; }
      try {
        final s = await ApiService.getAuthStatus();
        _gmailOk = s['authenticated'] == true;
        _email = s['email'] as String?;
      } catch (_) { _gmailOk = false; }
      try {
        final p = await ApiService.getStyleProfile();
        _profileOk = p != null;
      } catch (_) { _profileOk = false; }
      try {
        final replies = await ApiService.getReplies();
        _pendingCount = replies.where((r) => r['status'] == 'pending').length;
      } catch (_) { _pendingCount = 0; }
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
                child: ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 32), children: [

                  // ── Branded header ───────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.accent.withValues(alpha: 0.14),
                          AppTheme.purple.withValues(alpha: 0.07),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.22)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.35)),
                        ),
                        child: const Icon(Icons.auto_awesome_rounded, color: AppTheme.accent, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Gmail AI', style: AppTheme.ui(size: 20, weight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          _email ?? 'Auto-Reply Assistant',
                          style: AppTheme.ui(size: 12, color: AppTheme.textMute),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ])),
                      IconButton(
                        icon: Icon(
                          themeNotifier.isDark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          color: AppTheme.textSec,
                          size: 20,
                        ),
                        onPressed: themeNotifier.toggle,
                        tooltip: themeNotifier.isDark ? 'Switch to Light' : 'Switch to Dark',
                      ),
                      IconButton(
                        icon: Icon(Icons.refresh_rounded, color: AppTheme.textSec, size: 20),
                        onPressed: _refresh,
                        tooltip: 'Refresh',
                      ),
                    ]),
                  ),

                  const SizedBox(height: 28),

                  // ── System status ────────────────────────────────────
                  _SectionLabel('SYSTEM STATUS'),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(children: [
                      _StatusRow(icon: Icons.dns_rounded,       label: 'Backend Server', ok: _backendOk),
                      _StatusRow(icon: Icons.psychology_rounded, label: 'Ollama LLM',    ok: _ollamaOk),
                      _StatusRow(icon: Icons.mail_rounded,       label: 'Gmail Auth',    ok: _gmailOk),
                      _StatusRow(icon: Icons.person_rounded,     label: 'Style Profile', ok: _profileOk, isLast: true),
                    ]),
                  ),

                  const SizedBox(height: 24),

                  // ── Pending badge ────────────────────────────────────
                  if (_profileOk) ...[
                    _SectionLabel('OVERVIEW'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _pendingCount > 0
                              ? AppTheme.accent.withValues(alpha: 0.3)
                              : AppTheme.border,
                        ),
                      ),
                      child: Row(children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: (_pendingCount > 0 ? AppTheme.accent : AppTheme.textMute)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.pending_actions_rounded,
                            color: _pendingCount > 0 ? AppTheme.accent : AppTheme.textMute,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Pending Replies',
                              style: AppTheme.ui(size: 12, color: AppTheme.textSec)),
                          Text(
                            '$_pendingCount',
                            style: AppTheme.ui(
                              size: 26,
                              weight: FontWeight.w700,
                              color: _pendingCount > 0 ? AppTheme.accent : AppTheme.textMute,
                            ),
                          ),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Quick actions ────────────────────────────────────
                  _SectionLabel('ACTIONS'),
                  const SizedBox(height: 10),

                  if (!_gmailOk)
                    _ActionTile(
                      icon: Icons.login_rounded,
                      label: 'Connect Gmail',
                      bgColor: AppTheme.accent,
                      textColor: Colors.white,
                      onTap: _connectGmail,
                    ),

                  if (!_profileOk && _gmailOk)
                    _ActionTile(
                      icon: Icons.auto_awesome_rounded,
                      label: 'Setup Style Profile',
                      bgColor: AppTheme.purple,
                      textColor: Colors.white,
                      onTap: () => Navigator.pushNamed(context, '/setup').then((_) => _refresh()),
                    ),

                  _ActionTile(
                    icon: Icons.inbox_rounded,
                    label: 'Open Inbox',
                    onTap: () => Navigator.pushNamed(context, '/inbox'),
                  ),

                  if (_pendingCount > 0)
                    _ActionTile(
                      icon: Icons.pending_actions_rounded,
                      label: 'Pending Replies  ($_pendingCount)',
                      bgColor: AppTheme.accent.withValues(alpha: 0.1),
                      textColor: AppTheme.accent,
                      borderColor: AppTheme.accent.withValues(alpha: 0.3),
                      onTap: () => Navigator.pushNamed(context, '/replies').then((_) => _refresh()),
                    ),

                  _ActionTile(
                    icon: Icons.mark_email_read_rounded,
                    label: 'All Replies',
                    onTap: () => Navigator.pushNamed(context, '/replies').then((_) => _refresh()),
                  ),

                  _ActionTile(
                    icon: Icons.person_rounded,
                    label: 'Style Profile',
                    onTap: () => Navigator.pushNamed(context, '/profile'),
                  ),

                  if (_gmailOk)
                    _ActionTile(
                      icon: Icons.settings_rounded,
                      label: 'Setup / Retrain',
                      onTap: () => Navigator.pushNamed(context, '/setup').then((_) => _refresh()),
                    ),

                  if (_gmailOk)
                    _ActionTile(
                      icon: Icons.logout_rounded,
                      label: 'Logout',
                      textColor: AppTheme.red,
                      borderColor: AppTheme.red.withValues(alpha: 0.2),
                      onTap: () async {
                        await ApiService.logout();
                        _refresh();
                      },
                    ),
                ]),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTheme.ui(
        size: 10,
        weight: FontWeight.w700,
        color: AppTheme.textMute,
        letterSpacing: 1.4,
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool ok;
  final bool isLast;
  const _StatusRow({required this.icon, required this.label, required this.ok, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppTheme.green : AppTheme.red;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: color.withValues(alpha: 0.85)),
          ),
          const SizedBox(width: 12),
          Text(label, style: AppTheme.ui(size: 13, weight: FontWeight.w500)),
          const Spacer(),
          // StatusChip already handles the badge display
          StatusChip(label: '', ok: ok),
        ]),
      ),
      if (!isLast) Divider(height: 1, indent: 16, endIndent: 16, color: AppTheme.border),
    ]);
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? bgColor;
  final Color? textColor;
  final Color? borderColor;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    this.bgColor,
    this.textColor,
    this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: bgColor ?? AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor ?? AppTheme.border),
            ),
            child: Row(children: [
              Icon(icon, color: textColor ?? AppTheme.textPrim, size: 18),
              const SizedBox(width: 12),
              Text(label, style: AppTheme.ui(size: 13, weight: FontWeight.w500, color: textColor ?? AppTheme.textPrim)),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, color: (textColor ?? AppTheme.textPrim).withValues(alpha: 0.35), size: 18),
            ]),
          ),
        ),
      ),
    );
  }
}
