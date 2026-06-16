import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils/theme_rebuild_mixin.dart';

class RepliesScreen extends StatefulWidget {
  const RepliesScreen({super.key});
  @override
  State<RepliesScreen> createState() => _RepliesScreenState();
}

class _RepliesScreenState extends State<RepliesScreen> with SingleTickerProviderStateMixin, ThemeRebuildMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _replies = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService.getReplies();
      setState(() => _replies = r);
    } catch (_) {} finally {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _filter(String status) =>
      _replies.where((r) => r['status'] == status).toList();

  @override
  Widget build(BuildContext context) {
    final pending  = _filter('pending');
    final sent     = _filter('sent');
    final rejected = _filter('rejected');

    return Scaffold(
      appBar: AppBar(
        title: Text('Replies', style: AppTheme.ui(size: 16, weight: FontWeight.w700)),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load)],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: 'Pending (${pending.length})'),
            Tab(text: 'Sent (${sent.length})'),
            Tab(text: 'Rejected (${rejected.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _ReplyList(replies: pending,  showActions: true,  onRefresh: _load),
                _ReplyList(replies: sent,     showActions: false, onRefresh: _load),
                _ReplyList(replies: rejected, showActions: false, onRefresh: _load),
              ],
            ),
    );
  }
}

class _ReplyList extends StatelessWidget {
  final List<Map<String, dynamic>> replies;
  final bool showActions;
  final VoidCallback onRefresh;
  const _ReplyList({required this.replies, required this.showActions, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (replies.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.inbox_outlined, size: 40, color: AppTheme.textMute),
        const SizedBox(height: 12),
        Text('Nothing here yet', style: AppTheme.ui(size: 13, color: AppTheme.textMute)),
      ]));
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: replies.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _ReplyCard(
          reply: replies[i],
          showActions: showActions,
          onRefresh: onRefresh,
        ),
      ),
    );
  }
}

class _ReplyCard extends StatefulWidget {
  final Map<String, dynamic> reply;
  final bool showActions;
  final VoidCallback onRefresh;
  const _ReplyCard({required this.reply, required this.showActions, required this.onRefresh});

  @override
  State<_ReplyCard> createState() => _ReplyCardState();
}

class _ReplyCardState extends State<_ReplyCard> {
  bool _expanded = false;
  bool _sending  = false;
  bool _editing  = false;
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.reply['generated_reply'] ?? '');
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await ApiService.sendReply(
        gmailMessageId: widget.reply['gmail_message_id'],
        threadId: widget.reply['thread_id'] ?? widget.reply['gmail_message_id'],
        to: widget.reply['sender'] ?? '',
        subject: widget.reply['subject'] ?? '',
        replyBody: _ctrl.text,
      );
      widget.onRefresh();
      if (mounted) {
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

  Future<void> _reject() async {
    await ApiService.updateStatus(widget.reply['gmail_message_id'], 'rejected');
    widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.reply['status'] as String? ?? 'pending';
    final statusColor = {
      'sent':     AppTheme.green,
      'rejected': AppTheme.red,
      'pending':  AppTheme.accent,
    }[status] ?? AppTheme.border;
    final date = widget.reply['created_at'] as String? ?? '';
    final shortDate = date.length >= 10 ? date.substring(0, 10) : date;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: AppTheme.ui(
                    size: 9,
                    weight: FontWeight.w700,
                    color: statusColor,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const Spacer(),
              Text(shortDate, style: AppTheme.ui(size: 10, color: AppTheme.textMute)),
            ]),
            const SizedBox(height: 10),
            Text(
              widget.reply['subject'] ?? '(no subject)',
              style: AppTheme.ui(size: 13, weight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              'From: ${widget.reply['sender'] ?? ''}',
              style: AppTheme.ui(size: 11, color: AppTheme.textSec),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),

        // ── AI reply preview ────────────────────────────────
        if (widget.reply['generated_reply'] != null) ...[
          Divider(height: 1, color: AppTheme.border),
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(
                    'AI REPLY',
                    style: AppTheme.ui(
                      size: 9,
                      weight: FontWeight.w700,
                      color: AppTheme.textMute,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Spacer(),
                  if (widget.showActions && _expanded)
                    GestureDetector(
                      onTap: () => setState(() => _editing = !_editing),
                      child: Row(children: [
                        Icon(
                          _editing ? Icons.check_rounded : Icons.edit_rounded,
                          size: 12,
                          color: AppTheme.textMute,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _editing ? 'Done' : 'Edit',
                          style: AppTheme.ui(size: 10, color: AppTheme.textMute),
                        ),
                        const SizedBox(width: 8),
                      ]),
                    ),
                  Icon(
                    _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 16,
                    color: AppTheme.textMute,
                  ),
                ]),
                const SizedBox(height: 8),
                if (_expanded && _editing)
                  TextField(
                    controller: _ctrl,
                    maxLines: null,
                    style: AppTheme.mono(size: 12, height: 1.5),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppTheme.card,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
                      ),
                    ),
                  )
                else
                  Text(
                    widget.reply['generated_reply'] ?? '',
                    style: AppTheme.mono(size: 12, color: AppTheme.textSec, height: 1.5),
                    maxLines: _expanded ? null : 3,
                    overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  ),
              ]),
            ),
          ),
        ],

        // ── Action buttons ──────────────────────────────────
        if (widget.showActions) ...[
          Divider(height: 1, color: AppTheme.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              TextButton.icon(
                icon: const Icon(Icons.close_rounded, size: 14),
                label: Text('Reject', style: AppTheme.ui(size: 11)),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.red,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onPressed: _reject,
              ),
              const Spacer(),
              _sending
                  ? Row(children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                      ),
                      const SizedBox(width: 8),
                      Text('Sending...', style: AppTheme.ui(size: 11, color: AppTheme.textSec)),
                    ])
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.send_rounded, size: 13),
                      label: Text('Send',
                          style: AppTheme.ui(size: 11, weight: FontWeight.w600, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _send,
                    ),
            ]),
          ),
        ],
      ]),
    );
  }
}
