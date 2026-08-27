import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_markdown/flutter_markdown.dart';

import '../../core/app_theme.dart';
import '../../core/providers.dart';
import 'ai_service.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  List<AiChatMsg> get _messages => ref.watch(aiChatHistoryProvider);

  static const _quickChips = [
    'What is escrow?',
    'Show my bookings',
    'Explore Lahore',
    'Is perfume legal to send?',
    'Places to visit in Dubai',
    'Can I ship electronics to UK?',
    'Marketplace rules',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    ref.read(aiChatHistoryProvider.notifier).append(AiChatMsg(isUser: true, text: trimmed));
    setState(() => _sending = true);
    _controller.clear();
    _scrollToBottom();

    try {
      final service = ref.read(aiServiceProvider);
      // Build conversation history from recent messages (last 20).
      final history = ref
          .read(aiChatHistoryProvider)
          .where((m) => m.text.isNotEmpty)
          .toList()
          .reversed
          .take(20)
          .toList()
          .reversed
          .map((m) => {
                'role': m.isUser ? 'user' : 'assistant',
                'content': m.text,
              })
          .toList();
      final result = await service.chat(trimmed, history: history);
      if (mounted) {
        ref.read(aiChatHistoryProvider.notifier).append(AiChatMsg(
          isUser: false,
          text: result['reply']?.toString() ?? 'No response.',
          source: result['source']?.toString(),
          data: result['data'] as Map<String, dynamic>?,
        ));
        setState(() => _sending = false);
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ref.read(aiChatHistoryProvider.notifier).append(AiChatMsg(
          isUser: false,
          text: 'Sorry, something went wrong. Please try again.',
        ));
        setState(() => _sending = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text('Flyro AI', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Quick-action chips.
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _quickChips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                return ActionChip(
                  label: Text(_quickChips[i], style: const TextStyle(fontSize: 12)),
                  backgroundColor: AppTheme.surface,
                  shape: StadiumBorder(side: BorderSide(color: Colors.grey.shade300)),
                  onPressed: _sending ? null : () => _send(_quickChips[i]),
                );
              },
            ),
          ),
          const Divider(height: 1),

          // Message list.
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (context, i) {
                final msgs = _messages;
                if (i == msgs.length) {
                  return const _TypingBubble();
                }
                final msg = msgs[i];
                return _MessageBubble(msg: msg);
              },
            ),
          ),

          // Input bar.
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _sending ? null : _send,
                      decoration: InputDecoration(
                        hintText: 'Ask about Flyro...',
                        filled: true,
                        fillColor: const Color(0xFFF7F8FC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : () => _send(_controller.text),
                    icon: Icon(Icons.send_rounded, color: _sending ? Colors.grey : AppTheme.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets ──────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.msg});
  final AiChatMsg msg;

  @override
  Widget build(BuildContext context) {
    final isUser = msg.isUser;
    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
      decoration: BoxDecoration(
        color: isUser ? AppTheme.primary : AppTheme.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isUser ? 16 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isUser)
            Text(
              msg.text,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                height: 1.4,
              ),
            )
          else
            MarkdownBody(
              data: msg.text,
              shrinkWrap: true,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
                strong: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
                em: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.black87),
                listBullet: const TextStyle(fontSize: 14, color: Colors.black87),
                h1: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),
                h2: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
                h3: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87),
                blockSpacing: 8,
              ),
            ),
          if (msg.source != null && !isUser) ...[
            const SizedBox(height: 4),
            Text(
              msg.source == 'faq'
                  ? 'FAQ'
                  : msg.source == 'tool'
                      ? 'Live data'
                      : msg.source == 'policy'
                          ? 'Policy'
                          : msg.source == 'travel_guide'
                              ? 'Travel Guide'
                              : msg.source == 'legality_check'
                                  ? 'Legality Check'
                                  : msg.source == 'llm'
                                      ? 'AI'
                                      : '',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.primary,
              child: Icon(Icons.smart_toy, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 6),
          ],
          bubble,
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const CircleAvatar(
            radius: 14,
            backgroundColor: AppTheme.primary,
            child: Icon(Icons.smart_toy, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const SizedBox(
              width: 40,
              height: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Dot(delay: 0),
                  _Dot(delay: 150),
                  _Dot(delay: 300),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.delay});
  final int delay;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _anim = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -4 * _anim.value),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: Colors.grey.shade400, shape: BoxShape.circle),
          ),
        );
      },
    );
  }
}
