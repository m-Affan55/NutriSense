"""Neural text-to-speech for the NutriSense AI Coach.

Device-local TTS engines (Android TTS / Apple AVSpeech) produce robotic, often
mispronounced Urdu because most handsets ship without a high-quality ur-PK voice
pack. This service synthesises speech server-side using Microsoft's neural
voices, which are natural and fluent in Urdu.

Two things happen here:

1. ``sanitize_for_speech`` strips Markdown, emoji, URLs and stray punctuation.
   Any TTS engine reads "**Sehri (500 kcal)**" badly; the coach's replies are
   Markdown, so they must be cleaned before synthesis.
2. ``synthesize`` renders the cleaned text to MP3 bytes via ``edge-tts`` and
   caches the result in-process, because the coach repeats a lot of the same
   phrases (greetings, prompts, error messages).

NOTE: ``edge-tts`` talks to an unofficial Microsoft endpoint. It needs no API
key and costs nothing, which makes it ideal for demos, but it can change without
notice. For production, swap ``_synthesize_edge`` for the official Azure Speech
SDK -- the voice names are identical.
"""

from __future__ import annotations

import asyncio
import hashlib
import re
from collections import OrderedDict
from typing import Dict, Optional, Tuple

try:  # pragma: no cover - import guard so the API still boots without the dep
    import edge_tts

    EDGE_TTS_AVAILABLE = True
except Exception:  # pragma: no cover
    edge_tts = None  # type: ignore[assignment]
    EDGE_TTS_AVAILABLE = False


# --------------------------------------------------------------------------- #
# Voices
# --------------------------------------------------------------------------- #

# Microsoft neural voices. The ur-PK pair is genuinely natural Pakistani Urdu.
VOICES: Dict[str, Dict[str, str]] = {
    "ur": {"female": "ur-PK-UzmaNeural", "male": "ur-PK-AsadNeural"},
    "en": {"female": "en-US-AriaNeural", "male": "en-US-GuyNeural"},
    # South-Asian English, often a better fit for Pakistani users than en-US.
    "en-in": {"female": "en-IN-NeerjaNeural", "male": "en-IN-PrabhatNeural"},
}

DEFAULT_LANGUAGE = "ur"
DEFAULT_GENDER = "female"

# Urdu reads more clearly a little slower than the neural default.
RATE_BY_LANGUAGE = {"ur": "-8%", "en": "+0%", "en-in": "+0%"}

MAX_INPUT_CHARS = 3000


def resolve_voice(language: str, gender: str) -> Tuple[str, str]:
    """Map a language/gender pair to a voice name and speaking rate."""
    lang = (language or DEFAULT_LANGUAGE).strip().lower()
    if lang not in VOICES:
        lang = lang.split("-")[0]
    if lang not in VOICES:
        lang = DEFAULT_LANGUAGE

    gen = (gender or DEFAULT_GENDER).strip().lower()
    if gen not in ("male", "female"):
        gen = DEFAULT_GENDER

    return VOICES[lang][gen], RATE_BY_LANGUAGE.get(lang, "+0%")


# --------------------------------------------------------------------------- #
# Text sanitisation
# --------------------------------------------------------------------------- #

_CODE_FENCE = re.compile(r"```.*?```", re.DOTALL)
_INLINE_CODE = re.compile(r"`([^`]*)`")
_IMAGE = re.compile(r"!\[[^\]]*\]\([^)]*\)")
_LINK = re.compile(r"\[([^\]]*)\]\([^)]*\)")
_URL = re.compile(r"https?://\S+|www\.\S+")
_HEADING = re.compile(r"^\s{0,3}#{1,6}\s*", re.MULTILINE)
_BLOCKQUOTE = re.compile(r"^\s{0,3}>\s?", re.MULTILINE)
_HRULE = re.compile(r"^\s{0,3}([-*_])(?:\s*\1){2,}\s*$", re.MULTILINE)
_BULLET = re.compile(r"^\s*[-*+•●▪]\s+", re.MULTILINE)
_ORDERED = re.compile(r"^\s*\d+[.)]\s+", re.MULTILINE)
_EMPHASIS = re.compile(r"(\*\*|__|\*|_|~~)")
_TABLE_PIPE = re.compile(r"[|]+")
# Table separator rows ("|---|:--:|") survive pipe-stripping as "--- :--:",
# so strip runs of separator characters once the pipes are gone.
_SEPARATOR_RUN = re.compile(r"(?<!\S)[-–—:=~]{2,}(?!\S)")
_LONE_DASH = re.compile(r"(?<!\S)[-–—](?!\S)")
_EMPTY_PARENS = re.compile(r"\(\s*\)")
_COMMA_BEFORE_PUNCT = re.compile("," + r"\s*([.!?:;۔،])")
_TRAILING_COLON = re.compile(r"\s*[:;،]\s*$")
_MULTI_SPACE = re.compile(r"[ \t ]+")
_MULTI_NEWLINE = re.compile(r"\n{2,}")
_REPEATED_PUNCT = re.compile(r"([.,!?۔،])\1+")
_SPACE_BEFORE_PUNCT = re.compile(r"\s+([.,!?;:۔،])")
_DANGLING_PUNCT = re.compile(r"[#*_`~^<>{}\[\]\\/|=+]")

# Emoji and pictographic blocks. Kept explicit rather than using a dependency.
_EMOJI = re.compile(
    "["
    "\U0001f300-\U0001f5ff"  # symbols & pictographs
    "\U0001f600-\U0001f64f"  # emoticons
    "\U0001f680-\U0001f6ff"  # transport & map
    "\U0001f700-\U0001f77f"
    "\U0001f780-\U0001f7ff"
    "\U0001f800-\U0001f8ff"
    "\U0001f900-\U0001f9ff"  # supplemental symbols
    "\U0001fa00-\U0001faff"
    "\U00002190-\U000021ff"  # arrows
    "\U00002300-\U000023ff"  # misc technical
    "\U000025a0-\U000025ff"  # geometric shapes
    "\U00002600-\U000027bf"  # misc symbols & dingbats
    "\U00002b00-\U00002bff"
    "\U0000fe00-\U0000fe0f"  # variation selectors
    "\U0001f1e6-\U0001f1ff"  # regional indicators (flags)
    "\U00002194-\U00002199"
    "\U000020e3"
    "\U0000fe0f"
    "]+",
    flags=re.UNICODE,
)


def sanitize_for_speech(text: str) -> str:
    """Turn a Markdown coach reply into a clean, speakable sentence stream.

    Markdown markers, emoji, URLs and bracket noise all cause TTS engines to
    stutter, spell out symbols, or drop whole clauses. Line breaks become
    sentence boundaries so the voice pauses naturally between list items.
    """
    if not text:
        return ""

    out = text

    # Structural Markdown first.
    out = _CODE_FENCE.sub(" ", out)
    out = _INLINE_CODE.sub(r"\1", out)
    out = _IMAGE.sub(" ", out)
    out = _LINK.sub(r"\1", out)
    out = _URL.sub(" ", out)
    # "logMeal()" must not become "logMeal, " once brackets turn into pauses.
    out = _EMPTY_PARENS.sub(" ", out)
    out = _HRULE.sub(" ", out)
    out = _HEADING.sub("", out)
    out = _BLOCKQUOTE.sub("", out)
    out = _BULLET.sub("", out)
    out = _ORDERED.sub("", out)
    out = _EMPHASIS.sub("", out)
    out = _TABLE_PIPE.sub(" ", out)
    out = _SEPARATOR_RUN.sub(" ", out)
    out = _LONE_DASH.sub(",", out)

    # Emoji and pictographs.
    out = _EMOJI.sub(" ", out)

    # Parentheses read better as brief pauses than as spoken brackets.
    out = out.replace("(", ", ").replace(")", ", ")

    # Line breaks become sentence boundaries so the voice pauses per item.
    lines = [ln.strip() for ln in _MULTI_NEWLINE.sub("\n", out).split("\n")]
    parts = []
    for line in lines:
        if not line:
            continue
        if line[-1] not in ".!?۔،:;,":
            line += "."
        parts.append(line)
    out = " ".join(parts)

    # Remaining symbol noise and whitespace tidy-up.
    out = _DANGLING_PUNCT.sub(" ", out)
    out = _MULTI_SPACE.sub(" ", out)
    out = _SPACE_BEFORE_PUNCT.sub(r"\1", out)
    out = _REPEATED_PUNCT.sub(r"\1", out)
    out = re.sub(r"(?:,\s*){2,}", ", ", out)
    # A stripped URL or bracket can leave ",:" or a trailing ":" behind, which
    # the voice renders as an odd hanging pause.
    out = _COMMA_BEFORE_PUNCT.sub(r"\1", out)
    out = _MULTI_SPACE.sub(" ", out)
    out = _TRAILING_COLON.sub(".", out)

    return out.strip()


# --------------------------------------------------------------------------- #
# Cache
# --------------------------------------------------------------------------- #

_CACHE_MAX_ENTRIES = 128
_CACHE_MAX_BYTES = 32 * 1024 * 1024  # 32 MB ceiling, safe on small dynos

_cache: "OrderedDict[str, bytes]" = OrderedDict()
_cache_bytes = 0


def _cache_key(text: str, voice: str, rate: str) -> str:
    digest = hashlib.sha256(f"{voice}|{rate}|{text}".encode("utf-8")).hexdigest()
    return digest[:32]


def _cache_get(key: str) -> Optional[bytes]:
    audio = _cache.get(key)
    if audio is not None:
        _cache.move_to_end(key)
    return audio


def _cache_put(key: str, audio: bytes) -> None:
    global _cache_bytes
    if key in _cache:
        _cache_bytes -= len(_cache[key])
        del _cache[key]
    _cache[key] = audio
    _cache_bytes += len(audio)
    while _cache and (len(_cache) > _CACHE_MAX_ENTRIES or _cache_bytes > _CACHE_MAX_BYTES):
        _, evicted = _cache.popitem(last=False)
        _cache_bytes -= len(evicted)


def cache_stats() -> Dict[str, int]:
    return {"entries": len(_cache), "bytes": _cache_bytes}


# --------------------------------------------------------------------------- #
# Synthesis
# --------------------------------------------------------------------------- #


class TtsUnavailable(RuntimeError):
    """Raised when speech could not be synthesised; caller should fall back."""


async def _synthesize_edge(text: str, voice: str, rate: str, pitch: str = "+0Hz") -> bytes:
    if not EDGE_TTS_AVAILABLE:
        raise TtsUnavailable("edge-tts is not installed on the server")

    communicate = edge_tts.Communicate(text, voice, rate=rate, pitch=pitch)
    buffer = bytearray()
    async for chunk in communicate.stream():
        if chunk.get("type") == "audio" and chunk.get("data"):
            buffer.extend(chunk["data"])

    if not buffer:
        raise TtsUnavailable("TTS provider returned no audio")
    return bytes(buffer)


_URDU_SCRIPT_PATTERN = re.compile(r"[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]")


def detect_language(text: str, fallback_lang: str = DEFAULT_LANGUAGE) -> str:
    """Detect whether text is predominantly Urdu or English based on script.

    If a user has the app in English mode but chats with the AI in Urdu, the
    reply will be in Urdu. Routing Urdu script to an English neural voice causes
    NoAudioReceived / silence. Auto-detecting the script prevents this.
    """
    if _URDU_SCRIPT_PATTERN.search(text):
        return "ur"
    if re.search(r"[a-zA-Z]", text):
        return "en" if fallback_lang not in ("en", "en-in") else fallback_lang
    return fallback_lang


ELEVENLABS_VOICES: Dict[str, str] = {
    "female": "Xb7hH8MSUJpSbSDYk0k2",  # Alice (Warm, conversational, human multilingual)
    "male": "JBFqnCBsd6RMkjVDRZzb",    # George (Warm, conversational multilingual)
}


async def _synthesize_elevenlabs(text: str, voice_id: str, timeout: float = 20.0) -> bytes:
    from app.core.config import settings
    api_key = settings.ELEVENLABS_API_KEY
    if not api_key:
        raise TtsUnavailable("No ElevenLabs API key configured")

    import httpx
    url = f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}"
    headers = {
        "xi-api-key": api_key.strip(),
        "Content-Type": "application/json",
    }
    payload = {
        "text": text,
        "model_id": "eleven_multilingual_v2",
        "voice_settings": {
            "stability": 0.5,
            "similarity_boost": 0.8,
            "style": 0.15,
            "use_speaker_boost": True,
        },
    }

    async with httpx.AsyncClient() as client:
        res = await client.post(url, json=payload, headers=headers, timeout=timeout)
        if res.status_code == 200 and res.content:
            return res.content
        raise TtsUnavailable(f"ElevenLabs returned {res.status_code}: {res.text}")


async def synthesize(
    text: str,
    language: str = DEFAULT_LANGUAGE,
    gender: str = DEFAULT_GENDER,
    timeout: float = 20.0,
) -> Tuple[bytes, str, bool]:
    """Synthesise ``text`` to MP3 bytes.

    Returns ``(audio_bytes, voice_name, was_cached)``.
    Prefers hyper-realistic ElevenLabs neural voices, with seamless auto-failover
    to Microsoft Edge-TTS and on-device speech.
    """
    cleaned = sanitize_for_speech(text)[:MAX_INPUT_CHARS]
    if not cleaned:
        raise TtsUnavailable("Nothing speakable left after sanitisation")

    effective_lang = detect_language(cleaned, fallback_lang=language)
    voice, rate = resolve_voice(effective_lang, gender)
    key = _cache_key(cleaned, voice, rate)

    cached = _cache_get(key)
    if cached is not None:
        return cached, voice, True

    # Tier 1: ElevenLabs Hyper-Realistic Conversational Voice
    from app.core.config import settings
    if settings.ELEVENLABS_API_KEY:
        try:
            el_voice_id = ELEVENLABS_VOICES.get(gender, ELEVENLABS_VOICES["female"])
            audio = await _synthesize_elevenlabs(cleaned, el_voice_id, timeout=timeout)
            _cache_put(key, audio)
            return audio, f"elevenlabs-{el_voice_id}", False
        except Exception as e:
            print(f"[TTS] ElevenLabs synthesis failed, falling back to Edge-TTS: {e}")

    # Tier 2: Microsoft Edge-TTS (Free & Unlimited Fallback)
    try:
        audio = await asyncio.wait_for(_synthesize_edge(cleaned, voice, rate), timeout=timeout)
    except asyncio.TimeoutError as exc:
        raise TtsUnavailable(f"TTS provider timed out after {timeout}s") from exc
    except TtsUnavailable:
        raise
    except Exception as exc:  # network hiccup, endpoint change, etc.
        raise TtsUnavailable(f"TTS synthesis failed: {exc}") from exc

    _cache_put(key, audio)
    return audio, voice, False


async def warmup(language: str = DEFAULT_LANGUAGE) -> bool:
    """Pre-synthesise a short phrase so the first real request is fast.

    Useful on platforms that spin containers down when idle (e.g. Render free
    tier) and before a live demo.
    """
    phrase = "السلام علیکم" if language.startswith("ur") else "Hello"
    try:
        await synthesize(phrase, language=language, timeout=25.0)
        return True
    except TtsUnavailable:
        return False
