import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user_model.dart';
import '../../data/services/api_service.dart';

class SanctuaryChatWidget extends StatefulWidget {
  final ApiService apiService;
  final UserModel currentUser;
  final bool isDark;

  const SanctuaryChatWidget({
    super.key,
    required this.apiService,
    required this.currentUser,
    required this.isDark,
  });

  @override
  State<SanctuaryChatWidget> createState() => _SanctuaryChatWidgetState();
}

class _SanctuaryChatWidgetState extends State<SanctuaryChatWidget> {
  bool _isOpen = false;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  int _lastSeenCount = 0;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _refreshTimer;

  static const List<String> _quickEmojis = [
    '👍', '❤️', '🚀', '🎉', '🔥', '😂', '👏', '✨', '💡', '🛡️', '⚡', '☕'
  ];

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) _fetchMessages(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final list = await widget.apiService.getChatMessages();
      if (mounted) {
        setState(() {
          _messages = list;
          _isLoading = false;
          if (_isOpen) {
            _lastSeenCount = list.length;
          }
        });
        if (!silent && _isOpen) {
          _scrollToBottom();
        }
      }
    } catch (_) {
      if (mounted && !silent) setState(() => _isLoading = false);
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

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _textController.clear();

    final res = await widget.apiService.sendChatMessage(
      message: text,
      username: widget.currentUser.username,
      role: widget.currentUser.role,
      avatarUrl: widget.currentUser.avatarUrl,
    );

    if (mounted) {
      setState(() => _isSending = false);
      if (res['success'] == true) {
        await _fetchMessages(silent: true);
        _scrollToBottom();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Error al enviar mensaje'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _addEmoji(String emoji) {
    final cur = _textController.text;
    _textController.text = cur + emoji;
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: _textController.text.length),
    );
  }

  int get _unreadCount {
    if (_isOpen) return 0;
    final diff = _messages.length - _lastSeenCount;
    return diff > 0 ? diff : 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    if (!_isOpen) {
      // Closed Floating Bubble
      return Tooltip(
        message: 'Abrir Chat Comunitario (Reinicio diario a las 00:00)',
        child: InkWell(
          onTap: () {
            setState(() {
              _isOpen = true;
              _lastSeenCount = _messages.length;
            });
            _scrollToBottom();
          },
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF06B6D4).withOpacity(0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.forum_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Chat',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                if (_unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$_unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // Open Floating Chat Window
    return Container(
      width: 350,
      height: 480,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B132B).withOpacity(0.96) : Colors.white.withOpacity(0.98),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF06B6D4).withOpacity(0.25),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF0891B2), const Color(0xFF0E7490)]
                    : [const Color(0xFF06B6D4), const Color(0xFF0891B2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.forum_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Chat de la Comunidad',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        'Efímero · Se borra cada día a las 00:00',
                        style: TextStyle(color: Colors.white70, fontSize: 9.5),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 17),
                  tooltip: 'Actualizar mensajes',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _fetchMessages(),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 19),
                  tooltip: 'Cerrar ventana',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() => _isOpen = false),
                ),
              ],
            ),
          ),

          // Message stream area
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF06B6D4), strokeWidth: 2),
                  )
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, size: 36, color: Colors.grey.withOpacity(0.5)),
                            const SizedBox(height: 8),
                            const Text(
                              'Aún no hay mensajes hoy.',
                              style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '¡Sé el primero en saludar al equipo!',
                              style: TextStyle(fontSize: 10.5, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, idx) {
                          final msg = _messages[idx];
                          final sender = msg['username']?.toString() ?? 'Anónimo';
                          final isMe = sender.toLowerCase() == widget.currentUser.username.toLowerCase();
                          final content = msg['message']?.toString() ?? '';
                          final role = msg['role']?.toString().toLowerCase() ?? 'usuario';
                          final timeStr = msg['created_at']?.toString() ?? '';
                          String timeDisplay = '';
                          try {
                            final dt = DateTime.parse(timeStr).toLocal();
                            timeDisplay = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                          } catch (_) {
                            timeDisplay = '';
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (!isMe) ...[
                                  CircleAvatar(
                                    radius: 13,
                                    backgroundColor: role == 'admin'
                                        ? const Color(0xFF06B6D4)
                                        : (role == 'docente' ? AppTheme.emerald : Colors.blueGrey),
                                    child: Text(
                                      sender.isNotEmpty ? sender[0].toUpperCase() : '?',
                                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? const Color(0xFF06B6D4)
                                          : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(14),
                                        topRight: const Radius.circular(14),
                                        bottomLeft: Radius.circular(isMe ? 14 : 2),
                                        bottomRight: Radius.circular(isMe ? 2 : 14),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (!isMe)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                sender,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: Color(0xFF38BDF8)),
                                              ),
                                              if (role == 'admin') ...[
                                                const SizedBox(width: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF06B6D4).withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text('ADMIN', style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4))),
                                                ),
                                              ],
                                            ],
                                          ),
                                        Text(
                                          content,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                                          ),
                                        ),
                                        if (timeDisplay.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(
                                              timeDisplay,
                                              style: TextStyle(
                                                fontSize: 8.5,
                                                color: isMe ? Colors.white70 : Colors.grey,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),

          // Quick Emoji Bar
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              border: Border(
                top: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
              ),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _quickEmojis.length,
              itemBuilder: (ctx, i) {
                final em = _quickEmojis[i];
                return InkWell(
                  onTap: () => _addEmoji(em),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                    child: Center(
                      child: Text(em, style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                );
              },
            ),
          ),

          // Input Bar
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B132B) : Colors.white,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    minLines: 1,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      hintStyle: const TextStyle(fontSize: 12),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: _isSending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF06B6D4)))
                      : const Icon(Icons.send_rounded, color: Color(0xFF06B6D4), size: 20),
                  onPressed: _isSending ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
