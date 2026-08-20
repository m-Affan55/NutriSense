import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../../../core/api_client.dart';
import '../../../shared/widgets/custom_toast.dart';

class AiCoachScreen extends StatefulWidget {
  const AiCoachScreen({super.key});

  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  
  bool _isTyping = false;
  String _language = 'en';

  @override
  void initState() {
    super.initState();
    _loadLanguageAndGreeting();
  }

  Future<void> _loadLanguageAndGreeting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _language = prefs.getString('language') ?? 'en';
      
      // Load initial greeting based on selected language
      final greeting = _language == 'ur'
          ? 'ہیلو! میں آپ کا اے آئی نیوٹریشن کوچ ہوں۔ میں آج آپ کے غذائی اہداف حاصل کرنے میں کس طرح مدد کر سکتا ہوں؟'
          : 'Hello! I am your AI Nutrition Coach. How can I help you reach your dietary goals today?';
          
      _messages.add({
        'sender': _language == 'ur' ? 'کوچ' : 'Coach',
        'text': greeting,
        'isUser': false,
        'time': _formatTime(DateTime.now()),
      });
    });
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    setState(() {
      _messages.add({
        'sender': _language == 'ur' ? 'آپ' : 'You',
        'text': text,
        'isUser': true,
        'time': _formatTime(DateTime.now()),
      });
      _isTyping = true;
    });

    _scrollToBottom();

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Session invalid');

      // 1. Build chat history payload
      final List<Map<String, String>> historyPayload = [];
      // Skip the initial greeting and send the last 10 messages for token efficiency
      final startIdx = _messages.length > 11 ? _messages.length - 11 : 1;
      for (int i = startIdx; i < _messages.length - 1; i++) {
        historyPayload.add({
          'role': _messages[i]['isUser'] ? 'user' : 'model',
          'content': _messages[i]['text'],
        });
      }

      // 2. Query Uvicorn chat endpoint
      final url = Uri.parse('${ApiClient.getBaseUrl()}/coach/chat');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': user.id,
          'message': text,
          'history': historyPayload,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Server failed to respond: ${response.body}');
      }

      final data = jsonDecode(response.body);
      final reply = data['response'] ?? 'Sorry, I encountered an issue parsing the reply.';
      final escalationAlert = data['escalation_alert'];

      if (mounted) {
        setState(() {
          _messages.add({
            'sender': _language == 'ur' ? 'کوچ' : 'Coach',
            'text': reply,
            'isUser': false,
            'time': _formatTime(DateTime.now()),
            'escalationAlert': escalationAlert,
          });
          _isTyping = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTyping = false);
        CustomToast.show(context, 'Chat error: ${e.toString()}');
      }
    }

    _scrollToBottom();
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

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final title = _language == 'ur' ? 'اے آئی غذائی کوچ' : 'AI Nutrition Coach';
    final subtitle = _language == 'ur' ? 'آن لائن · مدد کے لیے تیار' : 'Online · Ready to help';
    final hint = _language == 'ur' 
        ? 'کھانے، ترکیبوں یا متبادل کے بارے میں پوچھیں...' 
        : 'Ask about meals, recipes, or swap options...';

    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.5),
            radius: 1.2,
            colors: [Color(0xFF1A2420), Color(0xFF0D0F14)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withAlpha(25),
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.colorScheme.primary.withAlpha(60)),
                      ),
                      child: Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Divider(color: Colors.white.withAlpha(15), height: 1),

              // Messages List
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length && _isTyping) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2430),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            _language == 'ur' ? 'ٹائپنگ...' : 'Typing...',
                            style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 13),
                          ),
                        ),
                      );
                    }
                    final msg = _messages[index];
                    return _buildChatMessage(
                      sender: msg['sender'],
                      message: msg['text'],
                      time: msg['time'],
                      isUser: msg['isUser'],
                      theme: theme,
                      escalationAlert: msg['escalationAlert'],
                    );
                  },
                ),
              ),

              // Input Bar
              Container(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 100),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0F14),
                  border: Border(top: BorderSide(color: Colors.white.withAlpha(15))),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161A22).withAlpha(230),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white.withAlpha(20)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              style: const TextStyle(color: Colors.white),
                              textDirection: _language == 'ur' ? TextDirection.rtl : TextDirection.ltr,
                              decoration: InputDecoration(
                                hintText: hint,
                                hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                          Container(
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00E676), Color(0xFF00BCD4)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                              onPressed: _sendMessage,
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildChatMessage({
    required String sender,
    required String message,
    required String time,
    required bool isUser,
    required ThemeData theme,
    Map<String, dynamic>? escalationAlert,
  }) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primary
              : const Color(0xFF1E2430),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: isUser ? const Radius.circular(18) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(18),
          ),
          border: isUser
              ? null
              : Border.all(color: Colors.white.withAlpha(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  sender,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: isUser
                        ? theme.colorScheme.onPrimary.withAlpha(180)
                        : theme.colorScheme.primary,
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 9,
                    color: isUser
                        ? theme.colorScheme.onPrimary.withAlpha(140)
                        : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.white.withAlpha(220),
                height: 1.4,
              ),
            ),
            if (escalationAlert != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withAlpha(50),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade600.withAlpha(100)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          escalationAlert['level'] == 'critical' 
                              ? Icons.warning_rounded 
                              : Icons.info_outline,
                          color: Colors.amber.shade400,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Safety Alert',
                          style: TextStyle(
                            color: Colors.amber.shade400,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      escalationAlert['message'] ?? '',
                      style: TextStyle(
                        color: Colors.amber.shade100,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                    if (escalationAlert['show_doctor_button'] == true) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: Icon(Icons.local_hospital, size: 16, color: Colors.amber.shade200),
                          label: Text(
                            'Find Affordable Care',
                            style: TextStyle(color: Colors.amber.shade200, fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.amber.shade600.withAlpha(100)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            CustomToast.show(context, 'Doctor Finder launching soon...', isError: false);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
