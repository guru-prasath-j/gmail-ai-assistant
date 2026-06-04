import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme.dart';

class RepliesScreen extends StatefulWidget {
  const RepliesScreen({super.key});
  @override
  State<RepliesScreen> createState() => _RepliesScreenState();
}

class _RepliesScreenState extends State<RepliesScreen> with SingleTickerProviderStateMixin {
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

  List<Map<String, dynamic>> _filter(String status) => _replies.where((r) => r['status'] == status).toList();

  @override
  Widget build(BuildContext context) {
    final pending = _filter('pending');
    final sent = _filter('sent');
    final rejected = _filter('rejected');

    return Scaffold(
      appBar: AppBar(
        title: Text('Replies', style: GoogleFonts.dmMono()),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load)],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.textPrim,
          unselectedLabelColor: AppTheme.textMute,
          labelStyle: GoogleFonts.dmMono(fontSize: 12),
          unselectedLabelStyle: GoogleFonts.dmMono(fontSize: 12),
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
                _ReplyList(replies: pending, showActions: true, onRefresh: _load),
                _ReplyList(replies: sent, showActions: false, onRefresh: _load),
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
        const Icon(Icons.inbox_outlined, size: 40, color: AppTheme.textMute),
        const SizedBox(height: 12),
        Text('Nothing here yet', style: GoogleFonts.dmMono(color: AppTheme.textMute, fontSize: 13)),
      ]));
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: replies.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _ReplyCard(reply: replies[i], showActions: showActions, onRefresh: onRefresh),
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
  bool _sending = false;
  bool _editing = false;
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reply sent!'), backgroundColor: AppTheme.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.red));
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
    final statusColor = {'sent': AppTheme.green, 'rejected': AppTheme.red, 'pending': AppTheme.accent}[status] ?? AppTheme.border;
    final date = (widget.reply['created_at'] as String? ?? '');
    final shortDate = date.length >= 10 ? date.substring(0, 10) : date;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: statusColor.withOpacity(0.4))),
                child: Text(status.toUpperCase(), style: GoogleFonts.dmMono(fontSize: 9, color: statusColor, letterSpacing: 1)),
              ),
              const Spacer(),
              Text(shortDate, style: GoogleFonts.dmMono(fontSize: 10, color: AppTheme.textMute)),
            ]),
            const SizedBox(height: 10),
            Text(widget.reply['subject'] ?? '(no subject)', style: GoogleFonts.dmMono(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrim), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text('From: ${widget.reply['sender'] ?? ''}', style: GoogleFonts.dmMono(fontSize: 11, color: AppTheme.textSec), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),

        // Generated reply
        if (widget.reply['generated_reply'] != null) ...[
          const Divider(height: 1, color: AppTheme.border),
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('AI REPLY', style: GoogleFonts.dmMono(fontSize: 9, color: AppTheme.textMute, letterSpacing: 1)),
                  const Spacer(),
                  if (widget.showActions && _expanded)
                    GestureDetector(
                      onTap: () => setState(() => _editing = !_editing),
                      child: Row(children: [
                        Icon(_editing ? Icons.check_rounded : Icons.edit_rounded, size: 12, color: AppTheme.textMute),
                        const SizedBox(width: 4),
                        Text(_editing ? 'Done' : 'Edit', style: GoogleFonts.dmMono(fontSize: 10, color: AppTheme.textMute)),
                        const SizedBox(width: 8),
                      ]),
                    ),
                  Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 16, color: AppTheme.textMute),
                ]),
                const SizedBox(height: 8),
                if (_expanded && _editing)
                  TextField(
                    controller: _ctrl,
                    maxLines: null,
                    style: GoogleFonts.dmMono(fontSize: 12, color: AppTheme.textPrim, height: 1.5),
                    decoration: InputDecoration(
                      filled: true, fillColor: AppTheme.card, isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.accent)),
                    ),
                  )
                else
                  Text(widget.reply['generated_reply'] ?? '', style: GoogleFonts.dmMono(fontSize: 12, color: AppTheme.textSec, height: 1.5), maxLines: _expanded ? null : 3, overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis),
              ]),
            ),
          ),
        ],

        // Action buttons
        if (widget.showActions) ...[
          const Divider(height: 1, color: AppTheme.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              TextButton.icon(
                icon: const Icon(Icons.close_rounded, size: 14),
                label: Text('Reject', style: GoogleFonts.dmMono(fontSize: 11)),
                style: TextButton.styleFrom(foregroundColor: AppTheme.red, minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                onPressed: _reject,
              ),
              const Spacer(),
              _sending
                  ? Row(children: [
                      const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)),
                      const SizedBox(width: 8),
                      Text('Sending...', style: GoogleFonts.dmMono(fontSize: 11, color: AppTheme.textSec)),
                    ])
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.send_rounded, size: 13),
                      label: Text('Send', style: GoogleFonts.dmMono(fontSize: 11, color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), minimumSize: Size.zero),
                      onPressed: _send,
                    ),
            ]),
          ),
        ],
      ]),
    );
  }
}
