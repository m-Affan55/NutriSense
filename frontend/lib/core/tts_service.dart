import 'dart:async';
import 'dart:convert';
import 'package:universal_io/io.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'api_client.dart';

/// Strips Markdown, emoji and symbol noise so speech engines read cleanly.
///
/// The coach replies in Markdown ("**سحری** (500 kcal)"). Fed to any TTS engine
/// verbatim, that produces stuttering, spelled-out asterisks and dropped
/// clauses. Mirrors `sanitize_for_speech` in the backend's tts_service.py, so
/// the server path and the on-device fallback speak identical text.
class SpeechSanitizer {
  SpeechSanitizer._();

  static final RegExp _codeFence = RegExp(r'```[\s\S]*?```');
  static final RegExp _inlineCode = RegExp(r'`([^`]*)`');
  static final RegExp _image = RegExp(r'!\[[^\]]*\]\([^)]*\)');
  static final RegExp _link = RegExp(r'\[([^\]]*)\]\([^)]*\)');
  static final RegExp _url = RegExp(r'(https?://\S+|www\.\S+)');
  static final RegExp _heading = RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true);
  static final RegExp _blockquote = RegExp(r'^\s{0,3}>\s?', multiLine: true);
  static final RegExp _hrule =
      RegExp(r'^\s{0,3}([-*_])(?:\s*\1){2,}\s*$', multiLine: true);
  static final RegExp _bullet = RegExp(r'^\s*[-*+•●▪]\s+', multiLine: true);
  static final RegExp _ordered = RegExp(r'^\s*\d+[.)]\s+', multiLine: true);
  static final RegExp _emphasis = RegExp(r'(\*\*|__|\*|_|~~)');
  static final RegExp _tablePipe = RegExp(r'\|+');
  // Table separator rows ("|---|:--:|") survive pipe-stripping as "--- :--:",
  // so strip runs of separator characters once the pipes are gone.
  static final RegExp _separatorRun = RegExp(r'(?<!\S)[-–—:=~]{2,}(?!\S)');
  static final RegExp _loneDash = RegExp(r'(?<!\S)[-–—](?!\S)');
  static final RegExp _emptyParens = RegExp(r'\(\s*\)');
  static final RegExp _commaBeforePunct = RegExp(',' r'\s*([.!?:;' '۔،' '])');
  static final RegExp _trailingColon = RegExp(r'\s*[:;' '،' r']\s*$');
  static final RegExp _symbolNoise = RegExp(r'[#*_`~^<>{}\[\]\\/|=+]');
  static final RegExp _multiSpace = RegExp(r'[ \t ]+');
  static final RegExp _multiNewline = RegExp(r'\n{2,}');
  static final RegExp _spaceBeforePunct = RegExp(r'\s+([.,!?;:۔،])');
  static final RegExp _repeatedComma = RegExp(r'(?:,\s*){2,}');

  /// Emoji / pictographic blocks. Explicit ranges beat pulling in a dependency.
  static final RegExp _emoji = RegExp(
    '['
    '\u{1F300}-\u{1F5FF}'
    '\u{1F600}-\u{1F64F}'
    '\u{1F680}-\u{1F6FF}'
    '\u{1F700}-\u{1F77F}'
    '\u{1F780}-\u{1F7FF}'
    '\u{1F800}-\u{1F8FF}'
    '\u{1F900}-\u{1F9FF}'
    '\u{1FA00}-\u{1FAFF}'
    '\u{1F1E6}-\u{1F1FF}'
    '\u{2190}-\u{21FF}'
    '\u{2300}-\u{23FF}'
    '\u{25A0}-\u{25FF}'
    '\u{2600}-\u{27BF}'
    '\u{2B00}-\u{2BFF}'
    '\u{FE00}-\u{FE0F}'
    '\u{20E3}'
    ']+',
    unicode: true,
  );

  static String clean(String input) {
    if (input.isEmpty) return '';

    var out = input;

    out = out.replaceAll(_codeFence, ' ');
    out = out.replaceAllMapped(_inlineCode, (m) => m.group(1) ?? '');
    out = out.replaceAll(_image, ' ');
    out = out.replaceAllMapped(_link, (m) => m.group(1) ?? '');
    out = out.replaceAll(_url, ' ');
    // "logMeal()" must not become "logMeal, " once brackets turn into pauses.
    out = out.replaceAll(_emptyParens, ' ');
    out = out.replaceAll(_hrule, ' ');
    out = out.replaceAll(_heading, '');
    out = out.replaceAll(_blockquote, '');
    out = out.replaceAll(_bullet, '');
    out = out.replaceAll(_ordered, '');
    out = out.replaceAll(_emphasis, '');
    out = out.replaceAll(_tablePipe, ' ');
    out = out.replaceAll(_separatorRun, ' ');
    out = out.replaceAll(_loneDash, ',');
    out = out.replaceAll(_emoji, ' ');

    // Brackets read better as short pauses than as spoken "open paren".
    out = out.replaceAll('(', ', ').replaceAll(')', ', ');

    // Each line becomes its own sentence so the voice pauses between items
    // instead of running a whole bullet list together in one breath.
    final lines = out.replaceAll(_multiNewline, '\n').split('\n');
    final parts = <String>[];
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      if (!'.!?۔،:;,'.contains(line[line.length - 1])) {
        line = '$line.';
      }
      parts.add(line);
    }
    out = parts.join(' ');

    out = out.replaceAll(_symbolNoise, ' ');
    out = out.replaceAll(_multiSpace, ' ');
    out = out.replaceAllMapped(_spaceBeforePunct, (m) => m.group(1) ?? '');
    out = out.replaceAll(_repeatedComma, ', ');
    // A stripped URL or bracket can leave ",:" or a trailing ":" behind, which
    // the voice renders as an odd hanging pause.
    out = out.replaceAllMapped(_commaBeforePunct, (m) => m.group(1) ?? '');
    out = out.replaceAll(_multiSpace, ' ');
    out = out.replaceAll(_trailingColon, '.');

    return out.trim();
  }
}

/// Resolves the right speech-recognition locale for a language.
///
/// Without an explicit `localeId`, `speech_to_text` listens with the device
/// default — usually English — so spoken Urdu is transcribed against an English
/// acoustic model and comes back as nonsense. Locale IDs are formatted
/// differently per platform (`ur_PK` on Android, `ur-PK` on iOS), so query the
/// device rather than hard-coding either form.
class SttLocales {
  SttLocales._();

  static final Map<String, String?> _cache = {};

  static String _norm(String id) => id.toLowerCase().replaceAll('-', '_');

  static Future<String?> resolve(stt.SpeechToText speech, String language) async {
    if (_cache.containsKey(language)) return _cache[language];

    try {
      final want = language == 'ur' ? 'ur' : 'en';
      final preferredRegion = language == 'ur' ? 'pk' : 'us';

      final locales = await speech.locales();
      final matches =
          locales.where((l) => _norm(l.localeId).startsWith(want)).toList();

      if (matches.isEmpty) return _cache[language] = null;

      final best = matches.firstWhere(
        (l) => _norm(l.localeId).contains(preferredRegion),
        orElse: () => matches.first,
      );
      return _cache[language] = best.localeId;
    } catch (_) {
      return _cache[language] = null;
    }
  }
}

/// Speaks coach replies, preferring server-side neural voices.
///
/// Two-tier by design:
///   1. `POST /coach/tts` renders the text with a Microsoft neural voice
///      (ur-PK-UzmaNeural). Natural, correctly pronounced Urdu.
///   2. If that is unreachable, slow, or the device is offline, fall back to
///      on-device `flutter_tts` with a tuned rate and the best available
///      ur-PK voice. Lower quality, but voice mode never breaks.
///
/// Both paths funnel into a single [onComplete] callback so callers don't need
/// to know which engine spoke — important for the voice-mode
/// speak -> listen -> speak loop.
class TtsService {
  TtsService._();

  static final TtsService instance = TtsService._();

  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _player = AudioPlayer();

  /// Fires once when an utterance finishes, whichever engine produced it.
  VoidCallback? onComplete;

  /// Fires when speech fails outright (both tiers unavailable).
  void Function(String message)? onError;

  bool _initialized = false;
  bool _speaking = false;

  /// Monotonic token; a new utterance invalidates in-flight older ones so a
  /// slow network response can't start playing over newer speech.
  int _utterance = 0;

  StreamSubscription<void>? _playerCompleteSub;
  Timer? _watchdog;

  /// Consecutive server failures. After [_maxFailures] we pause trying for
  /// [_cooldown] to avoid endless timeouts, then retry.
  int _serverFailures = 0;
  DateTime? _serverDisabledUntil;
  static const int _maxFailures = 5;
  static const Duration _cooldown = Duration(seconds: 30);

  /// Timeout for neural audio synthesis over network
  static const Duration _serverTimeout = Duration(seconds: 25);

  final Map<String, Map<String, String>?> _voiceCache = {};
  Directory? _cacheDir;

  bool get isSpeaking => _speaking;

  /// True when the last attempt used a neural server voice (for UI badges).
  bool lastUsedNeuralVoice = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await _flutterTts.setSharedInstance(true);
        await _flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          const [],
        );
      } catch (_) {}
    }

    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setVolume(1.0);
    } catch (_) {}

    _playerCompleteSub = _player.onPlayerComplete.listen(
      (_) => _fireComplete(_utterance),
      onError: (Object e) {
        debugPrint('[TTS] AudioPlayer playback error: $e');
        _fireError('playback failed: $e');
      },
    );

    _flutterTts.setCompletionHandler(() => _fireComplete(_utterance));
    _flutterTts.setErrorHandler((msg) => _fireError(msg.toString()));
  }

  /// Completes the current utterance exactly once.
  void _fireComplete(int token) {
    if (token != _utterance) return;
    if (!_speaking) return;
    _speaking = false;
    _watchdog?.cancel();
    _watchdog = null;
    onComplete?.call();
  }

  void _fireError(String message) {
    if (!_speaking) return;
    _speaking = false;
    _watchdog?.cancel();
    _watchdog = null;
    onError?.call(message);
  }

  void _armWatchdog(int token, String text) {
    _watchdog?.cancel();
    final estimate = Duration(
      milliseconds: 5000 + (text.length * 100).clamp(0, 120000),
    );
    _watchdog = Timer(estimate, () {
      if (token == _utterance && _speaking) {
        _fireComplete(token);
      }
    });
  }

  /// Speaks [rawText]. Markdown and emoji are stripped first.
  ///
  /// [language] is `'ur'` or `'en'`.
  Future<void> speak(String rawText, {required String language}) async {
    await init();
    await stop();

    final text = SpeechSanitizer.clean(rawText);
    if (text.isEmpty) {
      _speaking = true;
      _fireComplete(_utterance);
      return;
    }

    final token = ++_utterance;
    _speaking = true;
    _armWatchdog(token, text);

    // Auto-detect language from text so Urdu replies use Urdu neural voices
    // even if the user has the overall app interface set to English.
    final isUrduText = RegExp(r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]').hasMatch(text);
    final effectiveLanguage = isUrduText ? 'ur' : (language == 'ur' ? 'ur' : 'en');

    debugPrint('[TTS] Speaking text (length: ${text.length}, language: $effectiveLanguage, serverAvailable: $_serverAvailable)');

    if (_serverAvailable) {
      try {
        final file = await _neuralAudio(text, effectiveLanguage);
        if (token != _utterance) return; // superseded by a newer utterance
        if (file != null) {
          lastUsedNeuralVoice = true;
          debugPrint('[TTS] Playing neural audio file: ${file.path}');
          await _player.setVolume(1.0);
          await _player.play(DeviceFileSource(file.path));
          _armWatchdog(token, text);
          return;
        }
      } catch (e) {
        debugPrint('[TTS] Neural audio playback attempt failed: $e');
      }
    }

    if (token != _utterance) return;
    lastUsedNeuralVoice = false;
    debugPrint('[TTS] Falling back to on-device TTS engine ($effectiveLanguage)');
    try {
      await _speakOnDevice(text, effectiveLanguage);
    } catch (e) {
      debugPrint('[TTS] On-device TTS failed: $e');
      _fireError('$e');
    }
  }

  /// Stops any speech in progress.
  Future<void> stop({bool notifyComplete = false}) async {
    _utterance++;
    final wasSpeaking = _speaking;
    _speaking = false;
    _watchdog?.cancel();
    _watchdog = null;
    try {
      await _player.stop();
    } catch (_) {}
    try {
      await _flutterTts.stop();
    } catch (_) {}
    if (notifyComplete && wasSpeaking) onComplete?.call();
  }

  Future<void> dispose() async {
    await _playerCompleteSub?.cancel();
    _playerCompleteSub = null;
    _watchdog?.cancel();
    _watchdog = null;
    try {
      await _flutterTts.stop();
    } catch (_) {}
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> prewarm(String language) async {
    try {
      final uri = Uri.parse('${ApiClient.getBaseUrl()}/coach/tts/health')
          .replace(queryParameters: {'language': language});
      await http.get(uri).timeout(const Duration(seconds: 30));
    } catch (_) {}
  }

  // ----------------------------------------------------------------------- //
  // Tier 1: server-side neural voice
  // ----------------------------------------------------------------------- //

  bool get _serverAvailable {
    final until = _serverDisabledUntil;
    if (until == null) return true;
    if (DateTime.now().isAfter(until)) {
      _serverDisabledUntil = null;
      _serverFailures = 0;
      return true;
    }
    return false;
  }

  void _recordServerFailure() {
    _serverFailures++;
    if (_serverFailures >= _maxFailures) {
      _serverDisabledUntil = DateTime.now().add(_cooldown);
      debugPrint('[TTS] Circuit breaker tripped: pausing server TTS for ${_cooldown.inSeconds}s');
    }
  }

  /// Returns a playable MP3 file, from the on-disk cache or the backend.
  Future<File?> _neuralAudio(String text, String language) async {
    final dir = await _ensureCacheDir();
    if (dir == null) return null;

    final file = File('${dir.path}/${language}_${_stableHash(text)}.mp3');
    if (await file.exists() && await file.length() > 0) {
      _serverFailures = 0;
      debugPrint('[TTS] Cache hit for audio file: ${file.path}');
      return file;
    }

    try {
      final ttsUrl = '${ApiClient.getBaseUrl()}/coach/tts';
      debugPrint('[TTS] Requesting neural audio from: $ttsUrl for language: $language');
      final res = await http
          .post(
            Uri.parse(ttsUrl),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({'text': text, 'language': language}),
          )
          .timeout(_serverTimeout);

      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        await file.writeAsBytes(res.bodyBytes, flush: true);
        _serverFailures = 0;
        _pruneCache(dir);
        debugPrint('[TTS] Successfully received ${res.bodyBytes.length} bytes of neural audio');
        return file;
      }

      debugPrint('[TTS] Server returned status ${res.statusCode}: ${res.body}');
      _recordServerFailure();
      return null;
    } catch (e) {
      debugPrint('[TTS] Failed to reach server TTS endpoint: $e');
      _recordServerFailure();
      return null;
    }
  }

  Future<Directory?> _ensureCacheDir() async {
    if (_cacheDir != null) return _cacheDir;
    try {
      final tmp = await getTemporaryDirectory();
      final dir = Directory('${tmp.path}/tts_cache');
      if (!await dir.exists()) await dir.create(recursive: true);
      return _cacheDir = dir;
    } catch (_) {
      return null;
    }
  }

  Future<void> _pruneCache(Directory dir, {int keep = 60}) async {
    try {
      final files = (await dir.list().toList()).whereType<File>().toList();
      if (files.length <= keep) return;
      files.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
      for (final f in files.take(files.length - keep)) {
        try {
          await f.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// FNV-1a over UTF-16 code units.
  ///
  /// Dart's `String.hashCode` isn't guaranteed stable across runs, which would
  /// silently defeat the on-disk cache. This is.
  String _stableHash(String input) {
    var hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash ^= unit & 0xFF;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
      hash ^= (unit >> 8) & 0xFF;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  // ----------------------------------------------------------------------- //
  // Tier 2: on-device fallback
  // ----------------------------------------------------------------------- //

  Future<void> _speakOnDevice(String text, String language) async {
    final isUrdu = language == 'ur';
    final token = _utterance;

    try {
      await _flutterTts.setLanguage(isUrdu ? 'ur-PK' : 'en-US');
    } catch (_) {}

    final voice = await _bestVoice(isUrdu ? 'ur' : 'en');
    if (voice != null) {
      try {
        await _flutterTts.setVoice(voice);
      } catch (_) {}
    }

    try {
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(_rateFor(isUrdu));
    } catch (_) {}

    await _flutterTts.speak(text);
    // Voice lookup and engine setup above can take a second or two on a cold
    // start; restart the clock from the point speech actually begins.
    _armWatchdog(token, text);
  }

  /// flutter_tts speech-rate scales differ per platform: 1.0 is normal on
  /// Android, ~0.5 is normal on iOS. One hard-coded value sounds rushed on one
  /// platform and glacial on the other. Urdu phonemes need a little more time
  /// than English either way.
  double _rateFor(bool isUrdu) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) return isUrdu ? 0.42 : 0.5;
    return isUrdu ? 0.85 : 1.0;
  }

  /// Picks the highest-quality installed voice for a language.
  ///
  /// Android typically exposes both `ur-pk-x-...-local` (small, robotic) and
  /// `...-network` (much better) variants, and only picks the local one by
  /// default. Choosing explicitly is most of the perceived quality win in the
  /// fallback path.
  Future<Map<String, String>?> _bestVoice(String langPrefix) async {
    if (_voiceCache.containsKey(langPrefix)) return _voiceCache[langPrefix];

    try {
      final raw = await _flutterTts.getVoices;
      if (raw is! List) return _voiceCache[langPrefix] = null;

      final matches = <Map<String, String>>[];
      for (final entry in raw) {
        if (entry is! Map) continue;
        final name = (entry['name'] ?? '').toString();
        final locale = (entry['locale'] ?? '').toString();
        if (name.isEmpty || locale.isEmpty) continue;
        if (!locale.toLowerCase().replaceAll('_', '-').startsWith(langPrefix)) {
          continue;
        }
        matches.add({'name': name, 'locale': locale});
      }

      if (matches.isEmpty) return _voiceCache[langPrefix] = null;

      matches.sort((a, b) => _voiceScore(b).compareTo(_voiceScore(a)));
      return _voiceCache[langPrefix] = matches.first;
    } catch (_) {
      return _voiceCache[langPrefix] = null;
    }
  }

  int _voiceScore(Map<String, String> voice) {
    final name = voice['name']!.toLowerCase();
    final locale = voice['locale']!.toLowerCase();
    var score = 0;
    if (locale.contains('pk')) score += 8;
    if (name.contains('network')) score += 5;
    if (name.contains('neural')) score += 5;
    if (name.contains('enhanced') || name.contains('premium')) score += 4;
    if (name.contains('compact') || name.contains('local')) score -= 2;
    return score;
  }
}
