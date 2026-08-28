import 'package:flutter/material.dart';
import 'ai_coach_screen.dart';

class VoiceModeOverlay extends StatefulWidget {
  final VoiceAssistantState voiceState;
  final String recognizedText;
  final VoidCallback onClose;
  final VoidCallback onStopAudio;

  const VoiceModeOverlay({
    super.key,
    required this.voiceState,
    required this.recognizedText,
    required this.onClose,
    required this.onStopAudio,
  });

  @override
  State<VoiceModeOverlay> createState() => _VoiceModeOverlayState();
}

class _VoiceModeOverlayState extends State<VoiceModeOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(VoiceModeOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.voiceState == VoiceAssistantState.listening || widget.voiceState == VoiceAssistantState.speaking) {
      if (!_pulseController.isAnimating) _pulseController.repeat(reverse: true);
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Container(
      width: size.width,
      height: size.height,
      color: const Color(0xFF0D0F14).withAlpha(240), // ~95% opacity dark background
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48), // Spacer for centering text
                  Text(
                    _getStatusText(),
                    style: TextStyle(
                      color: Colors.white.withAlpha(200),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),
            
            // Middle: Animated Bubble
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    double scale = (widget.voiceState == VoiceAssistantState.listening || widget.voiceState == VoiceAssistantState.speaking)
                        ? _scaleAnimation.value
                        : 1.0;
                    
                    final color = _getBubbleColor(theme);
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          boxShadow: [
                            BoxShadow(
                              color: color.withAlpha(120),
                              blurRadius: 40 * scale,
                              spreadRadius: 10 * scale,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            
            // Bottom: Transcription Text and Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.voiceState == VoiceAssistantState.speaking)
                    ElevatedButton.icon(
                      onPressed: widget.onStopAudio,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withAlpha(30),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: const Icon(Icons.stop, color: Colors.redAccent),
                      label: const Text("Stop Speaking"),
                    )
                  else
                    Container(
                      constraints: BoxConstraints(
                        minHeight: 80, 
                        maxHeight: size.height * 0.3,
                      ),
                      alignment: Alignment.center,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Text(
                          widget.recognizedText.isEmpty ? "..." : widget.recognizedText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w400,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText() {
    switch (widget.voiceState) {
      case VoiceAssistantState.listening: return 'Listening...';
      case VoiceAssistantState.processing: return 'Thinking...';
      case VoiceAssistantState.speaking: return 'Speaking...';
      case VoiceAssistantState.error: return 'Error';
      default: return 'Voice Mode';
    }
  }

  Color _getBubbleColor(ThemeData theme) {
    if (widget.voiceState == VoiceAssistantState.listening) {
      return theme.colorScheme.primary; // Standard green
    } else if (widget.voiceState == VoiceAssistantState.processing) {
      return Colors.orangeAccent;
    } else if (widget.voiceState == VoiceAssistantState.speaking) {
      return theme.colorScheme.primary.withAlpha(200);
    } else if (widget.voiceState == VoiceAssistantState.error) {
      return Colors.redAccent;
    }
    return Colors.grey.withAlpha(128);
  }
}
