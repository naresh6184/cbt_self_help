import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'db_helper.dart';

// ================= DATA MODEL =================
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

// ================= CHAT INTERFACE =================
class ChatInterface extends StatefulWidget {
  final String activityType;
  final String headerText;

  const ChatInterface({
    super.key,
    required this.activityType,
    required this.headerText,
  });

  @override
  State<ChatInterface> createState() => _ChatInterfaceState();
}

class _ChatInterfaceState extends State<ChatInterface> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> chatMessages = [];

  final String _baseUrl = dotenv.env['BACKEND_URL']!;
  String? _sessionId;
  bool _isBotTyping = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ================= LOAD STORED CHAT =================
  Future<void> _loadMessages() async {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);

    String? stored;

    if (widget.activityType == 'weekly-activity') {
      final slot = _getCurrentSlot();
      stored = await DBHelper.getChat(dateStr, slot);
    }

    if (!mounted) return;

    setState(() {
      chatMessages = [];

      if (stored != null && stored.isNotEmpty) {
        final lines = stored.split("\n");

        for (final line in lines) {
          final isUser = line.startsWith("USER:");
          final content = line.substring(line.indexOf(']') + 1).trim();

          chatMessages.add(ChatMessage(
            text: content,
            isUser: isUser,
            timestamp: DateTime.now(),
          ));
        }
      }
    });

    _scrollToBottom();
  }

  // ================= SEND MESSAGE =================
  Future<void> _sendMessage() async {
    final raw = _chatController.text.trim();
    if (raw.isEmpty || _isBotTyping) return;

    final now = DateTime.now();

    final userMessage = ChatMessage(
      text: raw,
      isUser: true,
      timestamp: now,
    );

    setState(() => chatMessages.add(userMessage));

    _chatController.clear();
    _scrollToBottom();

    await _persistMessage(userMessage);
    await _getBotResponseFromApi(raw);
  }

  // ================= CALL API =================
  Future<void> _getBotResponseFromApi(String userInput) async {
    setState(() => _isBotTyping = true);

    final bool isNewSession = _sessionId == null;

    final Uri url = isNewSession
        ? Uri.parse("$_baseUrl/${widget.activityType}/start")
        : Uri.parse("$_baseUrl/${widget.activityType}/message");

    final Map<String, dynamic> body = isNewSession
        ? {'initial_entry': userInput}
        : {'session_id': _sessionId, 'user_input': userInput};

    try {
      final response = await http
          .post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (isNewSession) {
          _sessionId = data['session_id'];
        }

        final botText =
            data['question'] ?? data['message'] ?? "I've noted that.";

        final botMessage = ChatMessage(
          text: botText,
          isUser: false,
          timestamp: DateTime.now(),
        );

        setState(() => chatMessages.add(botMessage));

        if (data['done'] == true) {
          _sessionId = null;
        }

        await _persistMessage(botMessage);
      }
    } catch (_) {
      setState(() {
        chatMessages.add(ChatMessage(
          text: "Could not connect to server.",
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    } finally {
      setState(() => _isBotTyping = false);
      _scrollToBottom();
    }
  }

  // ================= SAVE CHAT =================
  Future<void> _persistMessage(ChatMessage message) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final formatted =
        "${message.isUser ? "USER" : "BOT"}: "
        "[${DateFormat.Hm().format(message.timestamp)}] "
        "${message.text}";

    if (widget.activityType == 'weekly-activity') {
      final slot = _getCurrentSlot();
      await DBHelper.saveChat(dateStr, slot, formatted);
    }
  }

  // ================= TIME SLOT =================
  String _getCurrentSlot() {
    final now = DateTime.now();

    // Clamp to 6 AM minimum
    int startHour = now.hour < 6 ? 6 : now.hour;

    // Clamp to 11 PM max (23)
    if (startHour >= 24) startHour = 23;

    final endHour = (startHour + 1) % 24;

    String formatHour(int h) {
      final suffix = h >= 12 ? "PM" : "AM";
      final display = h % 12 == 0 ? 12 : h % 12;
      return "$display:00 $suffix";
    }

    return "${formatHour(startHour)} - ${formatHour(endHour)}";
  }


  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: 120,
        maxHeight: 420,
      ),
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xfff2f2f7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8),
                itemCount:
                chatMessages.length + (_isBotTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == chatMessages.length && _isBotTyping) {
                    return _buildTypingIndicator();
                  }
                  return _buildMessageBubble(chatMessages[index]);
                },
              ),
            ),

            /// INPUT BAR
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              padding:
              const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatController,
                      enabled: !_isBotTyping,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText: "Type a message...",
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send,
                        color: Colors.deepPurple),
                    onPressed:
                    _isBotTyping ? null : _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= MESSAGE BUBBLE =================
  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;

    return Align(
      alignment:
      isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        constraints:
        const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFFE3FFFE)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 45),
              child: Text(
                message.text,
                style: const TextStyle(fontSize: 15),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Text(
                DateFormat.Hm().format(message.timestamp),
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(8.0),
      child: Text(
        "Bot is typing...",
        style: TextStyle(fontStyle: FontStyle.italic),
      ),
    );
  }
}
