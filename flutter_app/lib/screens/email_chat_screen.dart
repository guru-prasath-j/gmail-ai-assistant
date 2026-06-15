import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme.dart';

class EmailChatScreen extends StatefulWidget {
  final Map<String, dynamic> email;
  const EmailChatScreen({super.key, required this.email});

  @override
  State<EmailChatScreen> createState() => _EmailChatScreenState();
}

class _EmailChatScreenState extends State<EmailChatScreen> {
  String? _reply;
  bool _generating = false;
  bool _editing = false;
  bool _sending = false;
  late TextEditingController _editCtrl;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _editCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() { _generating = true; _editing = false; });
    try {
      final r = await ApiService.generateReply(
        gmailMessageId: widget.email['id'],
        threadId: widget.email['threadId'] ?? widget.email['id'],
        subject: widget.email['subject'] ?? '',
        sender: widget.email['from'] ?? '',
        body: widget.email['body'] ?? widget.email['snippet'] ?? '',
      );
      setState(() {
        _reply = r;
        _editCtrl.text = r;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) _showSnack('Error: $e', AppTheme.red);
    } finally {
      setState(() => _generating = false);
    }
  }

  Future<void> _regenerate() async {
    setState(() { _generating = true; _editing = false; });
    try {
      final r = await ApiService.regenerateReply(
        gmailMessageId: widget.email['id'],
        subject: widget.email['subject'] ?? '',
        sender: widget.email['from'] ?? '',
        body: widget.email['body'] ?? widget.email['snippet'] ?? '',
      );
      setState(() {
        _reply = r;
        _editCtrl.text = r;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) _showSnack('Error: $e', AppTheme.red);
    } finally {
      setState(() => _generating = false);
    }
  }

  Future<void> _send() async {
    final body = _editing ? _editCtrl.text : (_reply ?? '');
    if (body.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await ApiService.sendReply(
        gmailMessageId: widget.email['id'],
        threadId: widget.email['threadId'] ?? widget.email['id'],
        to: widget.email['from'] ?? '',
        subject: widget.email['subject'] ?? '',
        replyBody: body,
      );
      if (mounted) {
        _showSnack('Reply sent!', AppTheme.green);
        Navigator.pop(context, 'sent');
      }
    } catch (e) {
      if (mounted) _showSnack('Failed: $e', AppTheme.red);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: GoogleFonts.dmMono(fontSize: 12)), backgroundColor: color),
    );
  }

  String _senderInitials(String from) {
    final name = from.split('<').first.trim();
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _senderName(String from) {
    final name = from.split('<').first.trim();
    return name.isNotEmpty ? name : from;
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.email;
    final subject = email['subject'] ?? '(no subject)';
    final from = email['from'] ?? '';
    final body = (email['body'] as String? ?? '').isNotEmpty
        ? email['body'] as String
        : email['snippet'] as String? ?? '';
    final date = email['date'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(subject, style: GoogleFonts.dmMono(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrim), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(_senderName(from), style: GoogleFonts.dmMono(fontSize: 10, color: AppTheme.textMute), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
        actions: [
          if (_reply != null && !_generating)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Regenerate reply',
              onPressed: _regenerate,
            ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            children: [
              // ── Email received bubble ──────────────────────────
              _ChatBubble(
                isReceived: true,
                initials: _senderInitials(from),
                name: _senderName(from),
                time: date.length > 16 ? date.substring(0, 16) : date,
                child: SelectableText(
                  body,
                  style: GoogleFonts.dmMono(fontSize: 12.5, color: AppTheme.textPrim, height: 1.6),
                ),
              ),

              const SizedBox(height: 20),

              // ── AI reply bubble or loading ─────────────────────
              if (_generating)
                _TypingIndicator()
              else if (_reply != null) ...[
                _ChatBubble(
                  isReceived: false,
                  initials: 'AI',
                  name: 'You (AI Draft)',
                  time: 'draft',
                  accentColor: AppTheme.accent,
                  child: _editing
                      ? TextField(
                          controller: _editCtrl,
                          maxLines: null,
                          autofocus: true,
                          style: GoogleFonts.dmMono(fontSize: 12.5, color: AppTheme.textPrim, height: 1.6),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppTheme.card,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.accent)),
                            contentPadding: const EdgeInsets.all(10),
                          ),
                        )
                      : SelectableText(
                          _reply!,
                          style: GoogleFonts.dmMono(fontSize: 12.5, color: AppTheme.textPrim, height: 1.6),
                        ),
                ),
                const SizedBox(height: 8),
                // copy button row
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  _SmallButton(
                    icon: Icons.copy_rounded,
                    label: 'Copy',
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _editing ? _editCtrl.text : _reply!));
                      _showSnack('Copied!', AppTheme.green);
                    },
                  ),
                ]),
              ],

              const SizedBox(height: 80),
            ],
          ),
        ),

        // ── Bottom action bar ──────────────────────────────────────
        _BottomBar(
          hasReply: _reply != null,
          isGenerating: _generating,
          isSending: _sending,
          isEditing: _editing,
          onGenerate: _generate,
          onToggleEdit: () => setState(() {
            if (!_editing) _editCtrl.text = _reply ?? '';
            _editing = !_editing;
          }),
          onSend: _send,
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Widgets
// ─────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final bool isReceived;
  final String initials;
  final String name;
  final String time;
  final Widget child;
  final Color? accentColor;

  const _ChatBubble({
    required this.isReceived,
    required this.initials,
    required this.name,
    required this.time,
    required this.child,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isReceived ? AppTheme.surface : AppTheme.card;
    final borderColor = isReceived ? AppTheme.border : (accentColor ?? AppTheme.accent).withValues(alpha: 0.35);
    final avatarColor = isReceived ? AppTheme.purple : (accentColor ?? AppTheme.accent);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: isReceived ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: [
        if (isReceived) ...[
          _Avatar(initials: initials, color: avatarColor),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Column(
            crossAxisAlignment: isReceived ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: isReceived
                    ? [
                        Text(name, style: GoogleFonts.dmMono(fontSize: 11, color: AppTheme.textSec, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Text(time, style: GoogleFonts.dmMono(fontSize: 10, color: AppTheme.textMute)),
                      ]
                    : [
                        Text(time, style: GoogleFonts.dmMono(fontSize: 10, color: AppTheme.textMute)),
                        const SizedBox(width: 8),
                        Text(name, style: GoogleFonts.dmMono(fontSize: 11, color: accentColor ?? AppTheme.accent, fontWeight: FontWeight.w600)),
                      ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: isReceived ? Radius.zero : const Radius.circular(14),
                    topRight: isReceived ? const Radius.circular(14) : Radius.zero,
                    bottomLeft: const Radius.circular(14),
                    bottomRight: const Radius.circular(14),
                  ),
                  border: Border.all(color: borderColor),
                ),
                child: child,
              ),
            ],
          ),
        ),
        if (!isReceived) ...[
          const SizedBox(width: 10),
          _Avatar(initials: initials, color: avatarColor),
        ],
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String initials;
  final Color color;
  const _Avatar({required this.initials, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.18), shape: BoxShape.circle, border: Border.all(color: color.withValues(alpha: 0.4))),
      alignment: Alignment.center,
      child: Text(initials, style: GoogleFonts.dmMono(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(14),
            ),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
          ),
          child: AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.auto_awesome_rounded, size: 13, color: AppTheme.accent),
              const SizedBox(width: 8),
              Opacity(opacity: _anim.value, child: Text('AI is writing...', style: GoogleFonts.dmMono(fontSize: 12, color: AppTheme.accent))),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        const _Avatar(initials: 'AI', color: AppTheme.accent),
      ],
    );
  }
}

class _SmallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SmallButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppTheme.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: AppTheme.textSec),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.dmMono(fontSize: 11, color: AppTheme.textSec)),
        ]),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final bool hasReply, isGenerating, isSending, isEditing;
  final VoidCallback onGenerate, onToggleEdit, onSend;

  const _BottomBar({
    required this.hasReply,
    required this.isGenerating,
    required this.isSending,
    required this.isEditing,
    required this.onGenerate,
    required this.onToggleEdit,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: isGenerating
          ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)),
              const SizedBox(width: 12),
              Text('Generating reply...', style: GoogleFonts.dmMono(fontSize: 12, color: AppTheme.textSec)),
            ])
          : !hasReply
              ? SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: Text('Generate AI Reply', style: GoogleFonts.dmMono(fontSize: 13, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: onGenerate,
                  ),
                )
              : Row(children: [
                  OutlinedButton.icon(
                    icon: Icon(isEditing ? Icons.check_rounded : Icons.edit_rounded, size: 15),
                    label: Text(isEditing ? 'Done' : 'Edit', style: GoogleFonts.dmMono(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSec,
                      side: const BorderSide(color: AppTheme.border),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: onToggleEdit,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: isSending
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded, size: 15),
                      label: Text(isSending ? 'Sending...' : 'Send Reply', style: GoogleFonts.dmMono(fontSize: 13, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: isSending ? null : onSend,
                    ),
                  ),
                ]),
    );
  }
}
