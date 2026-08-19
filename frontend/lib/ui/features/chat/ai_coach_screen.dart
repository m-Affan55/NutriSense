import 'dart:ui';
import 'package:flutter/material.dart';

class AiCoachScreen extends StatefulWidget {
  const AiCoachScreen({super.key});

  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                        Text('AI Nutrition Coach',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            )),
                        Text('Online · Ready to help',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            )),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Divider(color: Colors.white.withAlpha(15), height: 1),

              // Messages List
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _buildChatMessage(
                      sender: 'Coach',
                      message:
                          'Hello! I am your AI Nutrition Coach. How can I help you reach your dietary goals today?',
                      time: '12:00 PM',
                      isUser: false,
                      theme: theme,
                    ),
                  ],
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
                              decoration: InputDecoration(
                                hintText: 'Ask about meals, recipes, or swap options...',
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
                              onPressed: () {},
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
            const SizedBox(height: 4),
            Text(
              message,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.white.withAlpha(220),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
