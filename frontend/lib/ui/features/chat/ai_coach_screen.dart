import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../core/api_client.dart';
import '../../../core/tts_service.dart';
import '../../../shared/widgets/custom_toast.dart';
import '../../../shared/widgets/islamic_decorations.dart';
import '../../../core/ramadan_controller.dart';
import '../../../core/reminder_manager.dart';
import 'clinic_finder_screen.dart';
import 'voice_mode_overlay.dart';

enum VoiceAssistantState {
  idle,
  listening,
  processing,
  speaking,
  error,
}

class AiCoachScreen extends StatefulWidget {
  const AiCoachScreen({super.key});

  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  
  bool _isTyping = false;
  String _language = 'en';
  String? _goal;
  List<String> _medicalConditions = [];

  // Voice features
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final TtsService _tts = TtsService.instance;
  VoiceAssistantState _voiceState = VoiceAssistantState.idle;
  bool _isVoiceModeOn = false;
  bool _isVoiceModeOverlayVisible = false;
  Timer? _silenceTimer;
  bool _isSttInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSpeechAndTts();
    _loadLanguageAndGreeting();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _stopVoiceFeaturesCleanly();
    }
  }

  void _stopVoiceFeaturesCleanly() {
    _silenceTimer?.cancel();
    if (_voiceState == VoiceAssistantState.speaking) {
      _tts.stop();
    }
    if (_voiceState == VoiceAssistantState.listening) {
      _speechToText.stop();
    }
    if (mounted) {
      setState(() {
        _voiceState = VoiceAssistantState.idle;
      });
    }
  }

  Future<void> _initSpeechAndTts() async {
    try {
      _isSttInitialized = await _speechToText.initialize(
        onError: (val) {
          if (!mounted) return;
          // "no match" and "speech timeout" fire routinely whenever the user
          // just says nothing. Treating those as failures latched the UI into
          // the error state and killed voice mode for the rest of the session.
          final msg = val.errorMsg;
          final routine = msg.contains('no_match') ||
              msg.contains('speech_timeout') ||
              msg.contains('retry');
          setState(() {
            _voiceState =
                routine ? VoiceAssistantState.idle : VoiceAssistantState.error;
          });
          if (!routine) {
            // Nothing else resets this state, so self-heal rather than leaving
            // the mic permanently red.
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted && _voiceState == VoiceAssistantState.error) {
                setState(() => _voiceState = VoiceAssistantState.idle);
              }
            });
          }
        },
      );
    } catch (e) {
      _isSttInitialized = false;
    }

    await _tts.init();

    // Both the neural server voice and the on-device fallback report through
    // these two callbacks, so the voice-mode loop doesn't care which spoke.
    _tts.onComplete = () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_isVoiceModeOn) {
          // Voice mode loop: done speaking -> start listening again
          _startListening();
        } else {
          setState(() => _voiceState = VoiceAssistantState.idle);
        }
      });
    };

    _tts.onError = (msg) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        CustomToast.show(context, 'TTS Error: $msg');
        setState(() => _voiceState = VoiceAssistantState.error);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _voiceState == VoiceAssistantState.error) {
            setState(() => _voiceState = VoiceAssistantState.idle);
          }
        });
      });
    };

    // The backend sleeps when idle on Render's free tier. Warming it means the
    // first reply gets the neural voice instead of timing out into the robotic
    // on-device fallback. Deliberately fired from _loadLanguageAndGreeting, once
    // _language is actually known — warming 'en' here would cache the wrong
    // voice for an Urdu user.
  }

  Future<bool> _requestPermissions() async {
    final micStatus = await Permission.microphone.request();
    final speechStatus = await Permission.speech.request();

    if (micStatus.isPermanentlyDenied || speechStatus.isPermanentlyDenied) {
      if (mounted) _showSettingsDialog();
      return false;
    }

    if (!micStatus.isGranted || !speechStatus.isGranted) {
      if (mounted) {
        CustomToast.show(context, 'Microphone permission is required for voice features.');
      }
      return false;
    }

    return true;
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text('Voice features require microphone and speech recognition access. Please enable them in app settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _startListening() async {
    // If we're already speaking, stop first
    if (_voiceState == VoiceAssistantState.speaking) {
      await _tts.stop();
    }

    final hasPermission = await _requestPermissions();
    if (!hasPermission || !mounted) return;

    if (!_isSttInitialized) {
      if (mounted) {
        CustomToast.show(context, 'Speech recognition not available on this device.');
      }
      return;
    }

    setState(() {
      _voiceState = VoiceAssistantState.listening;
      _controller.clear();
    });

    // Timeout logic: stop if no speech for 6 seconds
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 6), () {
      if (_voiceState == VoiceAssistantState.listening) {
        _stopListeningAndProcess();
      }
    });

    // Without an explicit locale the recognizer uses the device default
    // (usually English), so spoken Urdu comes back as garbled English.
    final localeId = await SttLocales.resolve(_speechToText, _language);
    if (!mounted) return;

    await _speechToText.listen(
      onResult: (result) {
        if (mounted) {
          setState(() {
            _controller.text = result.recognizedWords;
          });
          // Reset silence timer on new words
          _silenceTimer?.cancel();
          _silenceTimer = Timer(const Duration(seconds: 3), () {
            if (_voiceState == VoiceAssistantState.listening) {
              _stopListeningAndProcess();
            }
          });
        }
      },
      localeId: localeId,
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
      ),
    );
  }

  void _stopListeningAndProcess() async {
    _silenceTimer?.cancel();
    await _speechToText.stop();
    if (!mounted) return;

    // A reply is already in flight, so drop this turn — but still leave the UI
    // idle rather than stuck on "Listening..." with a dead microphone.
    if (_isTyping) {
      setState(() => _voiceState = VoiceAssistantState.idle);
      return;
    }

    setState(() => _voiceState = VoiceAssistantState.processing);
    // Auto-send if there's text
    if (_controller.text.trim().isNotEmpty) {
      _sendMessage();
    } else {
      setState(() => _voiceState = VoiceAssistantState.idle);
    }
  }

  void _toggleVoiceMode() {
    setState(() {
      _isVoiceModeOn = !_isVoiceModeOn;
      _isVoiceModeOverlayVisible = _isVoiceModeOn;
    });
    
    if (_isVoiceModeOn) {
      _startListening();
    } else {
      _stopVoiceFeaturesCleanly();
    }
  }

  Future<void> _speakText(String text) async {
    await _tts.stop();
    if (!mounted) return;
    setState(() {
      _voiceState = VoiceAssistantState.speaking;
    });

    // TtsService strips Markdown/emoji, prefers the neural ur-PK server voice,
    // and falls back to a tuned on-device voice if the backend is unreachable.
    await _tts.speak(text, language: _language);
  }

  /// Cuts the coach off mid-sentence ("Stop Audio").
  ///
  /// In voice mode this must hand straight back to the mic: stopping playback
  /// suppresses the completion callback that drives the speak -> listen loop, so
  /// without this the overlay would sit idle with no way forward but closing it.
  void _stopSpeaking() {
    _tts.stop();
    if (!mounted) return;
    if (_isVoiceModeOn) {
      _startListening();
    } else {
      setState(() => _voiceState = VoiceAssistantState.idle);
    }
  }

  Future<void> _loadLanguageAndGreeting() async {
    final prefs = await SharedPreferences.getInstance();
    
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user != null) {
        final healthRes = await supabase
            .from('health_profiles')
            .select('goal, medical_conditions')
            .eq('user_id', user.id)
            .maybeSingle();
        if (healthRes != null && mounted) {
          setState(() {
            _goal = healthRes['goal'];
            _medicalConditions = (healthRes['medical_conditions'] as List?)?.map((e) => e.toString()).toList() ?? [];
          });
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _language = prefs.getString('language') ?? prefs.getString('app_language') ?? 'en';
        
        final isRamadan = RamadanController.instance.isRamadanMode;
        String greeting;
        if (isRamadan) {
          greeting = _language == 'ur'
              ? '🌙 رمضان مبارک! میں آپ کا رمضان نیوٹریشن کوچ ہوں۔ سحری کے غذائی انتخاب، صحت مند افطار، اور روزے میں توانائی برقرار رکھنے سے متعلق کوئی بھی سوال پوچھیں!'
              : '🌙 Ramadan Mubarak! I am your Ramadan Nutrition Coach. Ask me anything about high-energy Sehri meals, balanced Iftar choices, hydration targets, and fasting recovery!';
        } else {
          greeting = _language == 'ur'
              ? 'ہیلو! میں آپ کا اے آئی نیوٹریشن کوچ ہوں۔ میں آج آپ کے غذائی اہداف حاصل کرنے میں کس طرح مدد کر سکتا ہوں؟'
              : 'Hello! I am your AI Nutrition Coach. How can I help you reach your dietary goals today?';
        }
            
        _messages.add({
          'sender': _language == 'ur' ? 'کوچ' : 'Coach',
          'text': greeting,
          'isUser': false,
          'time': _formatTime(DateTime.now()),
        });
      });
    }

    // Now that the language is known, wake the backend and pre-cache a phrase in
    // the right voice. Render spins idle containers down, so an un-warmed first
    // request can take tens of seconds and would silently degrade to the robotic
    // on-device voice.
    _tts.prewarm(_language);
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  Future<void> _sendMessage() async {
    // Guard against concurrent submissions while AI is already generating a response
    if (_isTyping) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // 1. Preemptive internet connectivity check
    final connectivityResults = await Connectivity().checkConnectivity();
    final isOnline = connectivityResults.any((r) => r != ConnectivityResult.none);
    if (!mounted) return; // Guard async gap
    if (!isOnline) {
      final noInternetMsg = _language == 'ur'
          ? 'انٹرنیٹ کنکشن نہیں ہے۔ براہ کرم اپنا نیٹ ورک چیک کریں۔'
          : 'No internet connection. Please check your network and try again.';
      CustomToast.show(context, noInternetMsg, isError: true);
      return;
    }

    _controller.clear();
    int userMsgIndex = -1;
    setState(() {
      _messages.add({
        'sender': _language == 'ur' ? 'آپ' : 'You',
        'text': text,
        'isUser': true,
        'time': _formatTime(DateTime.now()),
      });
      userMsgIndex = _messages.length - 1;
      _isTyping = true;
      if (_voiceState != VoiceAssistantState.processing) {
         _voiceState = VoiceAssistantState.processing;
      }
    });

    _scrollToBottom();

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Session invalid');

      // 1. Build chat history payload
      final List<Map<String, String>> historyPayload = [];
      final startIdx = _messages.length > 11 ? _messages.length - 11 : 1;
      for (int i = startIdx; i < _messages.length - 1; i++) {
        historyPayload.add({
          'role': _messages[i]['isUser'] ? 'user' : 'model',
          'content': _messages[i]['text'],
        });
      }

      // 2. Query Uvicorn chat endpoint with a 90-second timeout
      final url = Uri.parse('${ApiClient.getBaseUrl()}/coach/chat');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': user.id,
          'message': text,
          'history': historyPayload,
        }),
      ).timeout(const Duration(seconds: 90));

      if (response.statusCode != 200) {
        throw Exception('Server failed to respond: ${response.body}');
      }

      final data = jsonDecode(response.body);
      final reply = data['response'] ?? 'Sorry, I encountered an issue parsing the reply.';
      final escalationAlert = data['escalation_alert'];

      // Escalation handling
      if (escalationAlert != null) {
        ReminderManager.showRiskAlert(
          title: escalationAlert['level'] == 'critical' ? 'Urgent Clinical Safety Alert' : 'Dietary Health Alert',
          message: escalationAlert['message'] ?? 'Please review your nutrition advice.',
          level: escalationAlert['level'] ?? 'warning',
        );
        _showBlockingRiskDialog(escalationAlert);
      }

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

        // Speak the reply if Voice Mode is on
        if (_isVoiceModeOn) {
          _speakText(reply);
        } else {
          setState(() => _voiceState = VoiceAssistantState.idle);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _voiceState = VoiceAssistantState.error;
          // Remove the failed user message bubble from the chat view
          if (userMsgIndex != -1 && userMsgIndex < _messages.length) {
            _messages.removeAt(userMsgIndex);
          }
          // Restore text back to input field so user can edit and try again
          _controller.text = text;
        });

        final isTimeout = e is TimeoutException || e.toString().contains('TimeoutException');
        final errorToastMsg = isTimeout
            ? (_language == 'ur'
                ? 'سرور کا جواب دینے میں تاخیر ہو گئی۔ براہ کرم دوبارہ کوشش کریں۔'
                : 'Connection timed out. Please check your internet and try again.')
            : (_language == 'ur'
                ? 'رابطہ منقطع ہو گیا۔ براہ کرم انٹرنیٹ چیک کریں۔'
                : 'Could not reach AI Coach. Please check your internet connection.');

        CustomToast.show(context, errorToastMsg, isError: true);
        
        if (_isVoiceModeOn) {
          _speakText(_language == 'ur' ? 'معذرت، رابطہ نہیں ہو سکا۔' : 'Sorry, connection timed out.');
        } else {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _voiceState = VoiceAssistantState.idle);
          });
        }
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

  void _showBlockingRiskDialog(Map<String, dynamic> alert) {
    if (!mounted) return;
    final isCritical = alert['level'] == 'critical';
    final theme = Theme.of(context);
    showDialog(
      context: context,
      barrierDismissible: !isCritical, // Force dismissal only for critical alerts
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E232E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isCritical ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
              color: isCritical ? Colors.redAccent : Colors.amberAccent,
            ),
            const SizedBox(width: 8),
            Text(
              isCritical ? 'Urgent Safety Alert' : 'Dietary Alert',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          alert['message'] ?? 'A medical pattern or dietary conflict has been detected.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          if (!isCritical)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Dismiss', style: TextStyle(color: Colors.grey)),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClinicFinderScreen(
                    riskLevel: alert['level'] ?? 'warning',
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isCritical ? Colors.redAccent : theme.colorScheme.primary,
              foregroundColor: isCritical ? Colors.white : Colors.black,
            ),
            child: const Text('Find Clinic', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _silenceTimer?.cancel();
    _speechToText.cancel();
    // TtsService is a long-lived singleton, so detach this screen's callbacks
    // rather than disposing it — the audio player is reused on the next visit.
    _tts.onComplete = null;
    _tts.onError = null;
    _tts.stop();
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
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          RamadanBackgroundWrapper(
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
                    Expanded(
                      child: Column(
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
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                        ),
                        child: const Icon(Icons.local_hospital_rounded, color: Colors.redAccent, size: 18),
                      ),
                      tooltip: _language == 'ur' ? 'قریبی کلینکس اور ہسپتال' : 'Nearby Clinics & Hospitals',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ClinicFinderScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Divider(color: Colors.white.withAlpha(15), height: 1),

              // Voice Status Indicator (if active)
              if (_voiceState != VoiceAssistantState.idle)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: _getVoiceStateColor(theme).withAlpha(30),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_getVoiceStateIcon(), size: 16, color: _getVoiceStateColor(theme)),
                      const SizedBox(width: 8),
                      Text(
                        _getVoiceStateText(),
                        style: TextStyle(color: _getVoiceStateColor(theme), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      if (_voiceState == VoiceAssistantState.speaking) ...[
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            _stopSpeaking();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withAlpha(50),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('Stop Audio ⏹️', style: TextStyle(color: Colors.redAccent, fontSize: 10)),
                          ),
                        )
                      ]
                    ],
                  ),
                ),

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

              // Quick Ramadan & Nutrition Prompt Chips
              Container(
                height: 42,
                margin: const EdgeInsets.only(bottom: 6),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _getDynamicPrompts().map((prompt) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: _buildQuickPromptChip(
                        _language == 'ur' ? prompt.labelUrdu : prompt.labelEng,
                        prompt.color,
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Input Bar
              Container(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 100),
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
                          // Mic Button
                          GestureDetector(
                            onTap: () {
                              if (_voiceState == VoiceAssistantState.listening) {
                                _stopListeningAndProcess();
                              } else {
                                _startListening();
                              }
                            },
                            child: Container(
                              height: 40,
                              width: 40,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: _voiceState == VoiceAssistantState.listening 
                                    ? Colors.redAccent.withAlpha(80) 
                                    : Colors.white.withAlpha(10),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _voiceState == VoiceAssistantState.listening ? Icons.mic : Icons.mic_none,
                                color: _voiceState == VoiceAssistantState.listening ? Colors.redAccent : Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              enabled: !_isTyping,
                              style: const TextStyle(color: Colors.white),
                              textDirection: _language == 'ur' ? TextDirection.rtl : TextDirection.ltr,
                              decoration: InputDecoration(
                                hintText: _isTyping
                                    ? (_language == 'ur' ? 'کوچ جواب تیار کر رہا ہے...' : 'Coach is thinking...')
                                    : (_voiceState == VoiceAssistantState.listening ? 'Listening...' : hint),
                                hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                              onSubmitted: _isTyping ? null : (_) => _sendMessage(),
                            ),
                          ),
                          // Voice Mode Button (ChatGPT Style)
                          GestureDetector(
                            onTap: _isTyping ? null : _toggleVoiceMode,
                            child: Container(
                              height: 40,
                              width: 40,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: _isVoiceModeOn ? theme.colorScheme.primary : Colors.white.withAlpha(10),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isVoiceModeOn ? Icons.close : Icons.graphic_eq,
                                color: _isVoiceModeOn ? theme.colorScheme.onPrimary : Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                          Container(
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              gradient: _isTyping
                                  ? LinearGradient(
                                      colors: [Colors.grey.shade800, Colors.grey.shade700],
                                    )
                                  : const LinearGradient(
                                      colors: [Color(0xFF00E676), Color(0xFF00BCD4)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: _isTyping
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                                    )
                                  : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                              onPressed: _isTyping ? null : _sendMessage,
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
      if (_isVoiceModeOverlayVisible)
        VoiceModeOverlay(
          voiceState: _voiceState,
          recognizedText: _controller.text,
          onClose: () {
            setState(() {
              _isVoiceModeOn = false;
              _isVoiceModeOverlayVisible = false;
            });
            _stopVoiceFeaturesCleanly();
          },
          onStopAudio: () {
            _stopSpeaking();
          },
        ),
      ],
      ),
    );
  }

  // --- Voice UI Helpers ---
  Color _getVoiceStateColor(ThemeData theme) {
    switch (_voiceState) {
      case VoiceAssistantState.listening: return Colors.redAccent;
      case VoiceAssistantState.processing: return Colors.orangeAccent;
      case VoiceAssistantState.speaking: return theme.colorScheme.primary;
      case VoiceAssistantState.error: return Colors.red;
      default: return Colors.grey;
    }
  }
  
  IconData _getVoiceStateIcon() {
    switch (_voiceState) {
      case VoiceAssistantState.listening: return Icons.mic;
      case VoiceAssistantState.processing: return Icons.hourglass_empty;
      case VoiceAssistantState.speaking: return Icons.volume_up;
      case VoiceAssistantState.error: return Icons.error_outline;
      default: return Icons.mic_none;
    }
  }

  String _getVoiceStateText() {
    switch (_voiceState) {
      case VoiceAssistantState.listening: return 'Listening...';
      case VoiceAssistantState.processing: return 'Thinking...';
      case VoiceAssistantState.speaking: return 'Speaking...';
      case VoiceAssistantState.error: return 'Error';
      default: return '';
    }
  }
  // ------------------------

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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isUser) // Manual Read Aloud Button
                      GestureDetector(
                        onTap: () => _speakText(message),
                        child: const Padding(
                          padding: EdgeInsets.only(right: 8.0),
                          child: Icon(Icons.volume_up, size: 14, color: Colors.white70),
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
              ],
            ),
            const SizedBox(height: 6),
            _buildFormattedMessage(message, isUser, theme),
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
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ClinicFinderScreen(
                                  riskLevel: escalationAlert['level'] ?? 'warning',
                                ),
                              ),
                            );
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

  Widget _buildFormattedMessage(String message, bool isUser, ThemeData theme) {
    final lines = message.split('\n');
    List<Widget> lineWidgets = [];

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trimRight();
      if (line.trim().isEmpty) {
        lineWidgets.add(const SizedBox(height: 6));
        continue;
      }

      // Check for bullet point (* or -)
      bool isBullet = false;
      if (line.trimLeft().startsWith('* ') || line.trimLeft().startsWith('- ') || line.trimLeft().startsWith('• ')) {
        isBullet = true;
        line = line.trimLeft();
        line = line.substring(2).trimLeft();
      } else if (RegExp(r'^\d+\.\s').hasMatch(line.trimLeft())) {
        final trimmed = line.trimLeft();
        final match = RegExp(r'^(\d+\.)\s').firstMatch(trimmed)!;
        final prefix = match.group(1)!;
        final content = trimmed.substring(match.end).trimLeft();
        lineWidgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$prefix ',
                  style: TextStyle(
                    color: isUser ? Colors.white70 : const Color(0xFF00D2FF),
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
                Expanded(child: _buildInlineFormattedText(content, isUser, theme)),
              ],
            ),
          ),
        );
        continue;
      }

      if (isBullet) {
        lineWidgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: TextStyle(
                    color: isUser ? Colors.white70 : const Color(0xFF00D2FF),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Expanded(child: _buildInlineFormattedText(line, isUser, theme)),
              ],
            ),
          ),
        );
      } else {
        lineWidgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: _buildInlineFormattedText(line, isUser, theme),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lineWidgets,
    );
  }

  Widget _buildInlineFormattedText(String text, bool isUser, ThemeData theme) {
    final baseColor = isUser ? Colors.white : Colors.white.withValues(alpha: 0.92);
    final boldColor = isUser ? Colors.white : const Color(0xFFFFD166);

    List<InlineSpan> spans = [];
    final pattern = RegExp(r'\*\*(.*?)\*\*|\*(.*?)\*');
    int lastMatchEnd = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: TextStyle(color: baseColor, fontSize: 13.5, height: 1.4),
        ));
      }

      if (match.group(1) != null) {
        // Bold (**text**)
        spans.add(TextSpan(
          text: match.group(1),
          style: TextStyle(
            color: boldColor,
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
            height: 1.4,
          ),
        ));
      } else if (match.group(2) != null) {
        // Italic (*text*)
        spans.add(TextSpan(
          text: match.group(2),
          style: TextStyle(
            color: baseColor,
            fontStyle: FontStyle.italic,
            fontSize: 13.5,
            height: 1.4,
          ),
        ));
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: TextStyle(color: baseColor, fontSize: 13.5, height: 1.4),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  List<_PromptChipData> _getDynamicPrompts() {
    if (RamadanController.instance.isRamadanMode) {
      return [
        _PromptChipData('🌙 سحری کے بہترین کھانے', '🌙 Best Sehri foods for energy', const Color(0xFFFFD166)),
        _PromptChipData('💧 روزے میں پیاس سے بچاؤ', '💧 How to avoid thirst while fasting?', const Color(0xFF00D2FF)),
        _PromptChipData('🍲 صحت مند افطار کے طریقے', '🍲 Healthy Iftar meal ideas', const Color(0xFFFFD166)),
        _PromptChipData('⚡ روزے میں ورزش کا وقت', '⚡ Workout timing in Ramadan', const Color(0xFF00E676)),
      ];
    }

    List<_PromptChipData> prompts = [];
    
    // Medical condition based (Robust matching)
    final medStr = _medicalConditions.join(' ').toLowerCase();
    if (medStr.contains('diabete') || medStr.contains('sugar')) {
      prompts.add(_PromptChipData('🩸 ذیابیطس کے لیے بہترین خوراک', '🩸 Diabetic-friendly low GI meals', const Color(0xFFFF3B30)));
    }
    if (medStr.contains('blood pressure') || medStr.contains('hypertension') || medStr.contains('heart')) {
      prompts.add(_PromptChipData('🫀 دل اور بلڈ پریشر کی خوراک', '🫀 Low sodium & heart-healthy meals', const Color(0xFFFF9500)));
    }
    
    // Goal based (Robust matching)
    final goalStr = _goal?.toLowerCase() ?? '';
    if (goalStr.contains('muscle') || goalStr.contains('bulk')) {
      prompts.add(_PromptChipData('💪 پٹھوں کے لیے غذائی مشورہ', '💪 High calorie bulking meals', const Color(0xFF00E676)));
      prompts.add(_PromptChipData('🍗 ہائی پروٹین کھانے', '🍗 High protein meal ideas', const Color(0xFF00BCD4)));
    } else if (goalStr.contains('fat') || goalStr.contains('lose')) {
      prompts.add(_PromptChipData('⚡ وزن کم کرنے کا منصوبہ', '⚡ Fat loss nutrition advice', const Color(0xFFFFD166)));
      prompts.add(_PromptChipData('🥗 کم کیلوری والے کھانے', '🥗 Low calorie filling meals', const Color(0xFF00E676)));
    } else {
      prompts.add(_PromptChipData('⚖️ متوازن خوراک کے مشورے', '⚖️ Balanced maintenance meals', const Color(0xFF00E676)));
    }

    // Hydration (base)
    if (prompts.length < 4) {
      prompts.add(_PromptChipData('💧 پانی پینے کا ہدف', '💧 Daily hydration plan', const Color(0xFF00D2FF)));
    }

    return prompts.take(4).toList();
  }

  Widget _buildQuickPromptChip(String text, Color accent) {
    return GestureDetector(
      onTap: _isTyping
          ? null
          : () {
              _controller.text = text;
              _sendMessage();
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: accent.withAlpha(20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withAlpha(70)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_upward_rounded, size: 12, color: accent),
          ],
        ),
      ),
    );
  }
}

class _PromptChipData {
  final String labelUrdu;
  final String labelEng;
  final Color color;
  _PromptChipData(this.labelUrdu, this.labelEng, this.color);
}
