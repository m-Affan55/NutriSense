import 'package:flutter/material.dart';
import '../navigation/main_navigation_screen.dart';

class OnboardingChatScreen extends StatefulWidget {
  const OnboardingChatScreen({super.key});

  @override
  State<OnboardingChatScreen> createState() => _OnboardingChatScreenState();
}

class _OnboardingChatScreenState extends State<OnboardingChatScreen> {
  final List<Map<String, dynamic>> _messages = [];
  final Map<String, dynamic> _healthProfile = {};
  
  int _currentQuestionIndex = 0;
  bool _isTyping = false;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _questions = [
    {"key": "full_name", "type": "text", "text": "Assalam-o-Alaikum! I'm Zara, your personal nutrition guide 🌿 Let's set up your profile. What's your name?"},
    {"key": "age", "type": "number", "text": "Nice to meet you, {name}! How old are you?"},
    {"key": "gender", "type": "choice", "text": "What's your gender?", "options": ["Male", "Female", "Other"]},
    {"key": "weight_kg", "type": "number", "text": "What's your current weight in kilograms? (e.g. 70)"},
    {"key": "height_cm", "type": "number", "text": "And your height in centimeters? (e.g. 170)"},
    {"key": "goal", "type": "choice", "text": "Great! What's your main health goal?", "options": ["🔥 Lose Fat", "💪 Gain Muscle", "⚖️ Maintenance"]},
    {"key": "activity_level", "type": "choice", "text": "How active are you on a typical day?", "options": ["🛋️ Sedentary", "🚶 Lightly Active", "🏃 Moderately Active", "🏋️ Very Active"]},
    {"key": "medical_conditions", "type": "multi_select", "text": "Do you have any of these medical conditions? (Select all that apply)", "options": ["Diabetes", "Hypertension", "IBS", "Heart Disease", "None"]},
    {"key": "dietary_restrictions", "type": "multi_select", "text": "Any dietary restrictions?", "options": ["Halal Only", "Vegetarian", "Lactose-Free", "Gluten-Free", "None"]},
    {"key": "daily_budget_pkr", "type": "number", "text": "What's your daily food budget? (in PKR, e.g. 500)"},
    {"key": "done", "type": "done", "text": "Perfect! I have everything I need to build your personalized plan. Let me calculate your targets now... ✨"},
  ];

  @override
  void initState() {
    super.initState();
    _askNextQuestion();
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

  Future<void> _askNextQuestion() async {
    if (_currentQuestionIndex >= _questions.length) return;

    setState(() {
      _isTyping = true;
    });
    
    _scrollToBottom();
    
    // Simulate typing delay
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    final q = _questions[_currentQuestionIndex];
    String text = q['text'];
    
    if (text.contains("{name}")) {
      text = text.replaceAll("{name}", _healthProfile['full_name'] ?? '');
    }

    setState(() {
      _isTyping = false;
      _messages.add({"role": "bot", "text": text});
    });
    
    _scrollToBottom();

    if (q['type'] == 'done') {
      // Simulate loading and navigate
      await Future.delayed(const Duration(seconds: 2));
      debugPrint("Final Profile: $_healthProfile"); // For testing
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      }
    }
  }

  void _handleUserResponse(dynamic response, String displayText) {
    final currentQ = _questions[_currentQuestionIndex];
    _healthProfile[currentQ['key']] = response;

    setState(() {
      _messages.add({"role": "user", "text": displayText});
      _currentQuestionIndex++;
      _textController.clear();
    });

    _askNextQuestion();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primary,
              child: const Icon(Icons.smart_toy, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Text('Zara — Your Nutrition Guide', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return _buildTypingIndicator(theme);
                }
                final msg = _messages[index];
                return _buildChatBubble(msg['text'], msg['role'] == 'user', theme);
              },
            ),
          ),
          _buildInputArea(theme),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(ThemeData theme) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF161A22),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(theme, 0),
            const SizedBox(width: 4),
            _buildDot(theme, 200),
            const SizedBox(width: 4),
            _buildDot(theme, 400),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(ThemeData theme, int delay) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutSine,
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withAlpha((value * 255).toInt()),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildChatBubble(String text, bool isUser, ThemeData theme) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? null : const Color(0xFF161A22),
          gradient: isUser ? LinearGradient(
            colors: [theme.colorScheme.primary, const Color(0xFF00BCD4)],
          ) : null,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 20),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme) {
    if (_currentQuestionIndex >= _questions.length || _isTyping) {
      return const SizedBox.shrink();
    }

    final currentQ = _questions[_currentQuestionIndex];
    final type = currentQ['type'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        border: Border(top: BorderSide(color: Colors.white.withAlpha(20))),
      ),
      child: SafeArea(
        child: _buildInputForType(type, currentQ, theme),
      ),
    );
  }

  Widget _buildInputForType(String type, Map<String, dynamic> q, ThemeData theme) {
    if (type == 'text' || type == 'number') {
      return Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              keyboardType: type == 'number' ? TextInputType.number : TextInputType.text,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type your answer...',
                hintStyle: TextStyle(color: Colors.grey.shade600),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: const Color(0xFF0D0F14),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) {
                  _handleUserResponse(val.trim(), val.trim());
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: theme.colorScheme.primary,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: () {
                if (_textController.text.trim().isNotEmpty) {
                  _handleUserResponse(_textController.text.trim(), _textController.text.trim());
                }
              },
            ),
          ),
        ],
      );
    } else if (type == 'choice') {
      final options = q['options'] as List<String>;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((opt) {
          return ActionChip(
            label: Text(opt, style: const TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFF0D0F14),
            side: BorderSide(color: theme.colorScheme.primary.withAlpha(50)),
            onPressed: () => _handleUserResponse(opt, opt),
          );
        }).toList(),
      );
    } else if (type == 'multi_select') {
      final options = q['options'] as List<String>;
      // For simplicity in this demo, just treat as single select that completes the step
      // In real implementation, this would accumulate selections and have a "Done" button
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((opt) {
              return ActionChip(
                label: Text(opt, style: const TextStyle(color: Colors.white)),
                backgroundColor: const Color(0xFF0D0F14),
                side: BorderSide(color: theme.colorScheme.primary.withAlpha(50)),
                onPressed: () => _handleUserResponse([opt], opt), // Simplified
              );
            }).toList(),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}
