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

  bool _showEmojiPicker = false;
  int _selectedCategoryIndex = 0;

  static const List<Map<String, dynamic>> _emojiCategoryDefs = [
    {
      'icon': '😃',
      'label': 'Caras y Emociones',
      'emojis': [
        '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '😊', '😇',
        '🙂', '🙃', '😉', '😌', '😍', '🥰', '😘', '😗', '😙', '😚',
        '😋', '😛', '😝', '😜', '🤪', '🤨', '🧐', '🤓', '😎', '🥸',
        '🤩', '🥳', '😏', '😒', '😞', '😔', '😟', '😕', '🙁', '☹️',
        '😣', '😖', '😫', '😩', '🥺', '😢', '😭', '😤', '😠', '😡',
        '🤬', '🤯', '😳', '🥵', '🥶', '😱', '😨', '😰', '😥', '😓',
        '🤗', '🤔', '🤭', '🤫', '🤥', '😶', '😐', '😑', '😬', '🙄',
        '😯', '😦', '😧', '😮', '😲', '🥱', '😴', '🤤', '😪', '😵',
        '🤐', '🥴', '🤢', '🤮', '🤧', '😷', '🤒', '🤕', '🤑', '🤠',
      ],
    },
    {
      'icon': '👋',
      'label': 'Gestos y Personas',
      'emojis': [
        '👋', '🤚', '🖐️', '✋', '🖖', '👌', '🤌', '🤏', '✌️', '🤞',
        '🤟', '🤘', '🤙', '👈', '👉', '👆', '🖕', '👇', '☝️', '👍',
        '👎', '✊', '👊', '🤛', '🤜', '👏', '🙌', '👐', '🤲', '🤝',
        '🙏', '✍️', '💪', '🦾', '🧠', '🫀', '🫁', '👀', '👁️', '🧑‍💻',
        '👨‍🎓', '👩‍🎓', '👨‍🏫', '👩‍🏫', '🧑‍🔧', '👨‍🚒', '🧑‍🚀', '🕵️', '👮', '👑',
      ],
    },
    {
      'icon': '🐶',
      'label': 'Animales y Naturaleza',
      'emojis': [
        '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐨', '🐯',
        '🦁', '🐮', '🐷', '🐸', '🐵', '🐔', '🐧', '🐦', '🦆', '🦅',
        '🦉', '🦇', '🐺', '🐗', '🐴', '🦄', '🐝', '🐛', '🦋', '🐌',
        '🐞', '🐜', '🐢', '🐍', '🐙', '🦑', '🦐', '🦀', '🐡', '🐠',
        '🐟', '🐬', '🐳', '🐋', '🦈', '🌲', '🌳', '🌴', '🌱', '🌿',
        '🍀', '🌸', '🌺', '🌻', '🌹', '🌞', '⭐', '🌈', '🌧️', '⚡',
      ],
    },
    {
      'icon': '🍔',
      'label': 'Comida y Bebida',
      'emojis': [
        '🍏', '🍎', '🍐', '🍊', '🍋', '🍌', '🍉', '🍇', '🍓', '🫐',
        '🍈', '🍒', '🍑', '🥭', '🍍', '🥥', '🥑', '🍆', '🥕', '🌽',
        '🌶️', '🥒', '🍄', '🥜', '🌰', '🍞', '🥐', '🥖', '🧀', '🍖',
        '🍗', '🥩', '🥓', '🍔', '🍟', '🍕', '🌭', '🥪', '🌮', '🌯',
        '🍝', '🍜', '🍣', '🍦', '🍧', '🍨', '🍩', '🍪', '🎂', '🍰',
        '🍫', '🍬', '🍭', '☕', '🍵', '🧃', '🥤', '🍺', '🍻', '🍷',
      ],
    },
    {
      'icon': '🚀',
      'label': 'Viajes y Lugares',
      'emojis': [
        '🚀', '🛸', '✈️', '🛫', '🛬', '🚁', '🚗', '🚕', '🚙', '🚌',
        '🏎️', '🚓', '🚑', '🚒', '🚲', '🛵', '🏍️', '🚂', '🚆', '🚇',
        '🚢', '⛵', '🚤', '⚓', '🗺️', '🧭', '🏔️', '🌋', '🏖️', '🏝️',
        '🏛️', '🏟️', '🏰', '🗼', '🗽', '⛲', '⛺', '🏠', '🏡', '🏢',
        '🏣', '🏥', '🏦', '🏨', '🏪', '🏫', '🌅', '🌄', '🌉', '🎡',
      ],
    },
    {
      'icon': '💡',
      'label': 'Objetos y Tecnología',
      'emojis': [
        '💡', '📱', '📲', '💻', '⌨️', '🖥️', '🖨️', '🖱️', '💾', '💿',
        '📀', '🎥', '📷', '📸', '📹', '📞', '☎️', '📟', '📠', '📺',
        '📻', '🎙️', '⏱️', '⏰', '⏳', '⌛', '📡', '🔋', '🔌', '🔦',
        '🕯️', '🧯', '📦', '🏷️', '✉️', '📩', '📫', '📪', '📰', '🔑',
        '🗝️', '🔨', '🪓', '🔧', '🔩', '⚙️', '🧰', '🧲', '🔬', '🔭',
      ],
    },
    {
      'icon': '✨',
      'label': 'Símbolos y Formas',
      'emojis': [
        '✨', '🔥', '⭐', '🌟', '💫', '⚡', '💥', '💯', '💢', '🎉',
        '🎊', '🎈', '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍',
        '🤎', '💔', '❣️', '💕', '💞', '💓', '💗', '💖', '💘', '💝',
        '✅', '❌', '✔️', '✖️', '❓', '❗', '⚠️', '⛔', '🚫', '🔔',
        '🔕', '🎯', '🏆', '🥇', '🥈', '🥉', '💎', '🔮', '🧿', '🎵',
      ],
    },
    {
      'icon': '💼',
      'label': 'Trabajo y Estudio',
      'emojis': [
        '💼', '📁', '📂', '📄', '📃', '📑', '📊', '📈', '📉', '📋',
        '📌', '📍', '📎', '🖇️', '📏', '📐', '✂️', '🖊️', '🖋️', '✒️',
        '📝', '✏️', '🖍️', '🖌️', '🔍', '🔎', '🔒', '🔓', '🔏', '🔐',
        '📚', '📖', '📕', '📗', '📘', '📙', '🎓', '📜', '🏷️', '✉️',
        '📧', '💻', '🖥️', '🖨️', '🗂️', '🗃️', '🗄️', '🗑️', '⏰', '☕',
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    // 1. Immediately hydrate with persisted messages from today (never blank across sessions/logouts)
    _messages = widget.apiService.storage.getChatMessages();
    _lastSeenCount = _messages.length;
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

    setState(() {
      _isSending = true;
    });
    _textController.clear();

    final res = await widget.apiService.sendChatMessage(
      message: text,
      username: widget.currentUser.username,
      role: widget.currentUser.role,
      avatarUrl: widget.currentUser.avatarUrl,
    );

    if (mounted) {
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
      setState(() => _isSending = false);
    }
  }

  void _addEmoji(String emoji) {
    final text = _textController.text;
    final selection = _textController.selection;
    if (selection.start >= 0 && selection.end >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, emoji);
      _textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + emoji.length),
      );
    } else {
      _textController.text = text + emoji;
      _textController.selection = TextSelection.collapsed(offset: _textController.text.length);
    }
  }

  Future<void> _deleteMessage(Map<String, dynamic> msg) async {
    final msgId = msg['id'];
    setState(() {
      _messages.removeWhere((m) => m['id']?.toString() == msgId?.toString());
    });
    await widget.apiService.deleteSingleChatMessage(msgId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mensaje eliminado del chat'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _banUser(String sender) async {
    final cleanSender = sender.trim();
    if (cleanSender.toLowerCase() == 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No es posible banear al administrador principal'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.block_rounded, color: Colors.redAccent, size: 22),
            SizedBox(width: 8),
            Text('Banear usuario', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '¿Deseas suspender y banear permanentemente a @$cleanSender?\n\nEl usuario no podrá iniciar sesión en Sanctuary ni enviar más mensajes al chat.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Banear usuario'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await widget.apiService.banUserByUsername(cleanSender);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Usuario suspendido'),
            backgroundColor: res['success'] == true ? Colors.redAccent : Colors.orangeAccent,
          ),
        );
      }
    }
  }

  Widget _buildModerationMenu(Map<String, dynamic> msg, String sender, {required bool isMe}) {
    final isDark = widget.isDark;
    final isSenderAdmin = sender.trim().toLowerCase() == 'admin';

    return SizedBox(
      width: 20,
      height: 20,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: Icon(
          Icons.more_vert_rounded,
          size: 15,
          color: isMe ? Colors.white70 : (isDark ? Colors.white60 : Colors.black45),
        ),
        tooltip: 'Moderar mensaje',
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 6,
        onSelected: (action) {
          if (action == 'delete') {
            _deleteMessage(msg);
          } else if (action == 'ban') {
            _banUser(sender);
          }
        },
        itemBuilder: (ctx) => [
          const PopupMenuItem<String>(
            value: 'delete',
            height: 34,
            child: Row(
              children: [
                Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                SizedBox(width: 8),
                Text(
                  'Eliminar mensaje',
                  style: TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (!isSenderAdmin)
            const PopupMenuItem<String>(
              value: 'ban',
              height: 34,
              child: Row(
                children: [
                  Icon(Icons.block_rounded, size: 16, color: Colors.orangeAccent),
                  SizedBox(width: 8),
                  Text(
                    'Banear usuario',
                    style: TextStyle(fontSize: 12, color: Colors.orangeAccent, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
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
      // Closed Floating Bubble (Icon only, no text label, with unread badge)
      return Material(
        color: Colors.transparent,
        child: Tooltip(
          message: 'Abrir Chat Comunitario (Reinicio diario a las 00:00)',
          child: InkWell(
            onTap: () {
              setState(() {
                _isOpen = true;
                _lastSeenCount = _messages.length;
              });
              _scrollToBottom();
            },
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
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
                  child: const Center(
                    child: Icon(Icons.forum_rounded, color: Colors.white, size: 24),
                  ),
                ),
                if (_unreadCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? const Color(0xFF0B132B) : Colors.white,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        '$_unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // Open Floating Chat Window
    return Material(
      color: Colors.transparent,
      textStyle: TextStyle(
        fontFamily: 'Inter',
        decoration: TextDecoration.none,
        color: isDark ? Colors.white : Colors.black87,
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          fontFamily: 'Inter',
          decoration: TextDecoration.none,
          color: isDark ? Colors.white : Colors.black87,
        ),
        child: Container(
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
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      Text(
                        'Efímero · Se borra cada día a las 00:00',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 9.5,
                          decoration: TextDecoration.none,
                        ),
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
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '¡Sé el primero en saludar al equipo!',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.grey,
                                decoration: TextDecoration.none,
                              ),
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
                          final sender = (msg['username'] ?? msg['user'] ?? 'Anónimo').toString().trim();
                          final isMe = sender.toLowerCase() == widget.currentUser.username.toLowerCase();
                          final content = (msg['message'] ?? msg['text'] ?? '').toString();
                          final role = (msg['role'] ?? 'usuario').toString().toLowerCase();
                          final timeStr = (msg['created_at'] ?? msg['timestamp'] ?? '').toString();
                          final isAdmin = widget.currentUser.role.toLowerCase() == 'admin';

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
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
                                        // Sender Header Row
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(maxWidth: 135),
                                              child: Text(
                                                isMe ? 'Tú (${widget.currentUser.username})' : sender,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10.5,
                                                  color: isMe
                                                      ? Colors.white
                                                      : (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: isMe
                                                    ? Colors.white.withOpacity(0.25)
                                                    : (role == 'admin'
                                                        ? const Color(0xFF06B6D4).withOpacity(0.2)
                                                        : (role == 'docente' ? AppTheme.emerald.withOpacity(0.2) : Colors.blueGrey.withOpacity(0.2))),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                role.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 7.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: isMe
                                                      ? Colors.white
                                                      : (role == 'admin'
                                                          ? const Color(0xFF06B6D4)
                                                          : (role == 'docente' ? AppTheme.emerald : Colors.blueGrey)),
                                                ),
                                              ),
                                            ),
                                            if (isAdmin) ...[
                                              const SizedBox(width: 4),
                                              _buildModerationMenu(msg, sender, isMe: isMe),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 3),
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

          // Categorized Emoji Picker Window (Compact icon-only tabs)
          if (_showEmojiPicker)
            Container(
              height: 210,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: Border(
                  top: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Column(
                children: [
                  // Category Tabs Header: Icons only to minimize horizontal space
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF090D16) : const Color(0xFFEDF2F7),
                      border: Border(
                        bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: _emojiCategoryDefs.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final cat = entry.value;
                              final isSel = _selectedCategoryIndex == idx;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: Tooltip(
                                    message: cat['label'] as String,
                                    child: InkWell(
                                      onTap: () => setState(() => _selectedCategoryIndex = idx),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        height: 28,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isSel
                                              ? const Color(0xFF06B6D4)
                                              : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05)),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isSel ? const Color(0xFF06B6D4) : Colors.transparent,
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          cat['icon'] as String,
                                          style: const TextStyle(fontSize: 15, decoration: TextDecoration.none),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => setState(() => _showEmojiPicker = false),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.close, size: 16, color: isDark ? Colors.grey : Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Emoji Grid
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(6),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                        childAspectRatio: 1.1,
                      ),
                      itemCount: (_emojiCategoryDefs[_selectedCategoryIndex]['emojis'] as List<String>).length,
                      itemBuilder: (ctx, i) {
                        final em = (_emojiCategoryDefs[_selectedCategoryIndex]['emojis'] as List<String>)[i];
                        return InkWell(
                          onTap: () => _addEmoji(em),
                          borderRadius: BorderRadius.circular(8),
                          hoverColor: const Color(0xFF06B6D4).withOpacity(0.15),
                          child: Center(
                            child: Text(
                              em,
                              style: const TextStyle(fontSize: 20, decoration: TextDecoration.none),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B132B) : Colors.white,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                // Emoji Toggle Button
                Tooltip(
                  message: _showEmojiPicker ? 'Ocultar emojis' : 'Seleccionar emoji',
                  child: IconButton(
                    icon: Icon(
                      _showEmojiPicker ? Icons.keyboard_alt_outlined : Icons.emoji_emotions_outlined,
                      color: _showEmojiPicker ? const Color(0xFF06B6D4) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      size: 22,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => setState(() => _showEmojiPicker = !_showEmojiPicker),
                  ),
                ),
                const SizedBox(width: 4),

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
    ),
  ),
);
  }
}
