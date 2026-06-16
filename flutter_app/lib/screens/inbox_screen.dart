import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils/theme_rebuild_mixin.dart';
import 'email_chat_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});
  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> with ThemeRebuildMixin {
  List<Map<String, dynamic>> _emails = [];
  bool _loading = true;
  String? _error;
  final Set<String> _generating = {};
  final Map<String, String> _replies = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final emails = await ApiService.getInbox(maxResults: 20, unreadOnly: false);
      setState(() => _emails = emails);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _generate(Map<String, dynamic> email) async {
    final id = email['id'] as String;
    setState(() => _generating.add(id));
    try {
      final reply = await ApiService.generateReply(
        gmailMessageId: id,
        threadId: email['threadId'] ?? id,
        subject: email['subject'] ?? '',
        sender: email['from'] ?? '',
        body: email['body'] ?? email['snippet'] ?? '',
      );
      setState(() => _replies[id] = reply);
      if (mounted) _showReplySheet(email, reply);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.red),
        );
      }
    } finally {
      setState(() => _generating.remove(id));
    }
  }

  void _showReplySheet(Map<String, dynamic> email, String reply) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ReplySheet(email: email, reply: reply),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inbox', style: AppTheme.ui(size: 16, weight: FontWeight.w700)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? (_error!.contains('401') ||
                      _error!.contains('not connected') ||
                      _error!.contains('Not authenticated') ||
                      _error!.contains('Gmail not connected')
                  ? _AuthErrorState(
                      onGoHome: () => Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false),
                    )
                  : _ErrorState(error: _error!, onRetry: _load))
              : _emails.isEmpty
                  ? Center(
                      child: Text('No emails found',
                          style: AppTheme.ui(color: AppTheme.textMute)),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _emails.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final email = _emails[i];
                          final id = email['id'] as String;
                          return _EmailTile(
                            email: email,
                            hasReply: _replies.containsKey(id),
                            isGenerating: _generating.contains(id),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => EmailChatScreen(email: email)),
                            ).then((_) => _load()),
                            onGenerate: () => _generate(email),
                            onViewReply: _replies.containsKey(id)
                                ? () => _showReplySheet(email, _replies[id]!)
                                : null,
                          );
                        },
                      ),
                    ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Email tile
// ─────────────────────────────────────────────────────────────

class _EmailTile extends StatelessWidget {
  final Map<String, dynamic> email;
  final bool hasReply, isGenerating;
  final VoidCallback onTap;
  final VoidCallback onGenerate;
  final VoidCallback? onViewReply;

  const _EmailTile({
    required this.email,
    required this.hasReply,
    required this.isGenerating,
    required this.onTap,
    required this.onGenerate,
    this.onViewReply,
  });

  String _initials(String from) {
    final name = from.split('<').first.trim();
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  // Consistent avatar color per sender
  Color _avatarColor(String from) {
    final colors = [
      AppTheme.purple,
      AppTheme.green,
      AppTheme.accent,
      const Color(0xFF2196F3),
      const Color(0xFF009688),
    ];
    return colors[from.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final unread = email['unread'] == true;
    final from = email['from'] as String? ?? '';
    final avatarColor = _avatarColor(from);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasReply
                ? AppTheme.green.withValues(alpha: 0.4)
                : AppTheme.border,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Sender avatar
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: avatarColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: avatarColor.withValues(alpha: 0.35)),
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials(from),
                  style: AppTheme.ui(
                    size: 12,
                    weight: FontWeight.w700,
                    color: avatarColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Subject + unread dot
                Row(children: [
                  if (unread)
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.only(right: 7, top: 1),
                      decoration: const BoxDecoration(
                        color: AppTheme.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      email['subject'] ?? '(no subject)',
                      style: AppTheme.ui(
                        size: 13,
                        weight: unread ? FontWeight.w700 : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
                const SizedBox(height: 3),
                Text(
                  from,
                  style: AppTheme.ui(size: 11, color: AppTheme.textSec),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Text(
                  email['snippet'] ?? '',
                  style: AppTheme.mono(size: 11, color: AppTheme.textMute, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ])),
            ]),
          ),

          Divider(height: 1, color: AppTheme.border),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Text(
                (email['date'] as String? ?? '').length > 16
                    ? (email['date'] as String).substring(0, 16)
                    : (email['date'] ?? ''),
                style: AppTheme.ui(size: 10, color: AppTheme.textMute),
              ),
              const Spacer(),
              if (hasReply && onViewReply != null)
                TextButton(
                  onPressed: onViewReply,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.green,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  child: Text('View Reply', style: AppTheme.ui(size: 11, color: AppTheme.green)),
                ),
              const SizedBox(width: 6),
              isGenerating
                  ? Row(children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                      ),
                      const SizedBox(width: 8),
                      Text('Generating...', style: AppTheme.ui(size: 11, color: AppTheme.textSec)),
                    ])
                  : ElevatedButton.icon(
                      icon: Icon(
                        hasReply ? Icons.refresh_rounded : Icons.auto_awesome_rounded,
                        size: 13,
                      ),
                      label: Text(
                        hasReply ? 'Regen' : 'Generate',
                        style: AppTheme.ui(size: 11, weight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasReply ? AppTheme.surface : AppTheme.accent,
                        foregroundColor: hasReply ? AppTheme.textPrim : Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        side: hasReply ? BorderSide(color: AppTheme.border) : BorderSide.none,
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: onGenerate,
                    ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Reply bottom sheet
// ─────────────────────────────────────────────────────────────

class _ReplySheet extends StatefulWidget {
  final Map<String, dynamic> email;
  final String reply;
  const _ReplySheet({required this.email, required this.reply});

  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  late TextEditingController _ctrl;
  bool _editing = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.reply);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await ApiService.sendReply(
        gmailMessageId: widget.email['id'],
        threadId: widget.email['threadId'] ?? widget.email['id'],
        to: widget.email['from'] ?? '',
        subject: widget.email['subject'] ?? '',
        replyBody: _ctrl.text,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reply sent!'), backgroundColor: AppTheme.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.red),
        );
      }
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('AI-Generated Reply',
                    style: AppTheme.ui(size: 15, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  'To: ${widget.email['from'] ?? ''}',
                  style: AppTheme.ui(size: 11, color: AppTheme.textMute),
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() => _editing = !_editing),
                icon: Icon(
                  _editing ? Icons.check_circle_outline_rounded : Icons.edit_rounded,
                  color: _editing ? AppTheme.green : AppTheme.textSec,
                  size: 20,
                ),
                tooltip: _editing ? 'Done editing' : 'Edit reply',
              ),
            ]),
          ),
          Divider(color: AppTheme.border, height: 20),
          Expanded(
            child: SingleChildScrollView(
              controller: ctrl,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _editing
                  ? TextField(
                      controller: _ctrl,
                      maxLines: null,
                      autofocus: true,
                      style: AppTheme.mono(size: 13, height: 1.6),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTheme.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
                        ),
                      ),
                    )
                  : Text(_ctrl.text, style: AppTheme.mono(size: 13, height: 1.7)),
            ),
          ),
          Divider(color: AppTheme.border, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Row(children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Discard', style: AppTheme.ui(color: AppTheme.textSec)),
              ),
              const Spacer(),
              ElevatedButton.icon(
                icon: _sending
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, size: 15),
                label: Text(
                  _sending ? 'Sending...' : 'Send Reply',
                  style: AppTheme.ui(size: 13, weight: FontWeight.w600, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _sending ? null : _send,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Error states
// ─────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.red, size: 40),
          const SizedBox(height: 16),
          Text(error, style: AppTheme.ui(size: 12, color: AppTheme.red), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text('Retry', style: AppTheme.ui(weight: FontWeight.w600)),
            onPressed: onRetry,
          ),
        ]),
      ),
    );
  }
}

class _AuthErrorState extends StatelessWidget {
  final VoidCallback onGoHome;
  const _AuthErrorState({required this.onGoHome});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
            ),
            child: const Icon(Icons.lock_outline_rounded, color: AppTheme.accent, size: 30),
          ),
          const SizedBox(height: 20),
          Text('Gmail Not Connected',
              style: AppTheme.ui(size: 16, weight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(
            'Please login with your Gmail account\nfrom the home screen.',
            style: AppTheme.ui(size: 13, color: AppTheme.textMute, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            icon: const Icon(Icons.home_rounded, size: 16),
            label: Text('Go to Home', style: AppTheme.ui(weight: FontWeight.w600, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: onGoHome,
          ),
        ]),
      ),
    );
  }
}
