"""
Kalpkrut Beats - Music Streaming API & Gateway Server  (v3.0.0)

Live JioSaavn catalog gateway with:
  * Real-time trending, charts, new releases, featured & editorial playlists
  * Albums, artists, playlists, lyrics, search (songs / albums / artists / playlists)
  * Autocomplete suggestions and smart "up next" related-song logic
  * Indian languages first (Hindi, Punjabi, Tamil, Telugu, Marathi, ...)
  * Session-wise (time-of-day, IST) playlists refreshed hourly
  * Optional Spotify India new-release discovery (resolved to playable JioSaavn tracks)
  * YouTube (yt-dlp) stream / search / download endpoints
  * 320kbps DES media decryption (PyCryptodome or built-in pure-Python fallback)

Runs on Render/Heroku (gunicorn server:app) and Vercel (zero-config Flask).
"""

import os
import re
import sys
import json
import html
import time
import uuid
import base64
import tempfile
import threading
import subprocess
import urllib.request
import urllib.parse
from datetime import datetime, timedelta, timezone
from concurrent.futures import ThreadPoolExecutor

from flask import Flask, request, jsonify, redirect, send_from_directory, render_template
from flask_cors import CORS

try:
    from Crypto.Cipher import DES as PyCryptoDES
    PYCRYPTO_AVAILABLE = True
except ImportError:
    PYCRYPTO_AVAILABLE = False

try:
    import yt_dlp
    YTDLP_AVAILABLE = True
except ImportError:
    YTDLP_AVAILABLE = False


VERSION = "3.0.0"
SERVICE_NAME = "Kalpkrut Beats API Gateway"
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
IS_VERCEL = bool(os.environ.get("VERCEL"))
IST = timezone(timedelta(hours=5, minutes=30))


# ═══════════════════════════════════════════════════════════════════════════════
# DES decryption (JioSaavn encrypted_media_url)
# ═══════════════════════════════════════════════════════════════════════════════
_IP = [58, 50, 42, 34, 26, 18, 10, 2, 60, 52, 44, 36, 28, 20, 12, 4,
       62, 54, 46, 38, 30, 22, 14, 6, 64, 56, 48, 40, 32, 24, 16, 8,
       57, 49, 41, 33, 25, 17, 9, 1, 59, 51, 43, 35, 27, 19, 11, 3,
       61, 53, 45, 37, 29, 21, 13, 5, 63, 55, 47, 39, 31, 23, 15, 7]
_FP = [40, 8, 48, 16, 56, 24, 64, 32, 39, 7, 47, 15, 55, 23, 63, 31,
       38, 6, 46, 14, 54, 22, 62, 30, 37, 5, 45, 13, 53, 21, 61, 29,
       36, 4, 44, 12, 52, 20, 60, 28, 35, 3, 43, 11, 51, 19, 59, 27,
       34, 2, 42, 10, 50, 18, 58, 26, 33, 1, 41, 9, 49, 17, 57, 25]
_PC1 = [57, 49, 41, 33, 25, 17, 9, 1, 58, 50, 42, 34, 26, 18,
        10, 2, 59, 51, 43, 35, 27, 19, 11, 3, 60, 52, 44, 36,
        63, 55, 47, 39, 31, 23, 15, 7, 62, 54, 46, 38, 30, 22,
        14, 6, 61, 53, 45, 37, 29, 21, 13, 5, 28, 20, 12, 4]
_PC2 = [14, 17, 11, 24, 1, 5, 3, 28, 15, 6, 21, 10,
        23, 19, 12, 4, 26, 8, 16, 7, 27, 20, 13, 2,
        41, 52, 31, 37, 47, 55, 30, 40, 51, 45, 33, 48,
        44, 49, 39, 56, 34, 53, 46, 42, 50, 36, 29, 32]
_SHIFTS = [1, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1]
_E = [32, 1, 2, 3, 4, 5, 4, 5, 6, 7, 8, 9,
      8, 9, 10, 11, 12, 13, 12, 13, 14, 15, 16, 17,
      16, 17, 18, 19, 20, 21, 20, 21, 22, 23, 24, 25,
      24, 25, 26, 27, 28, 29, 28, 29, 30, 31, 32, 1]
_S_BOX = [
    [[14,4,13,1,2,15,11,8,3,10,6,12,5,9,0,7],[0,15,7,4,14,2,13,1,10,6,12,11,9,5,3,8],[4,1,14,8,13,6,2,11,15,12,9,7,3,10,5,0],[15,12,8,2,4,9,1,7,5,11,3,14,10,0,6,13]],
    [[15,1,8,14,6,11,3,4,9,7,2,13,12,0,5,10],[3,13,4,7,15,2,8,14,12,0,1,10,6,9,11,5],[0,14,7,11,10,4,13,1,5,8,12,6,9,3,2,15],[13,8,10,1,3,15,4,2,11,6,7,12,0,5,14,9]],
    [[10,0,9,14,6,3,15,5,1,13,12,7,11,4,2,8],[13,7,0,9,3,4,6,10,2,8,5,14,12,11,15,1],[13,6,4,9,8,15,3,0,11,1,2,12,5,10,14,7],[1,10,13,0,6,9,8,7,4,15,14,3,11,5,2,12]],
    [[7,13,14,3,0,6,9,10,1,2,8,5,11,12,4,15],[13,8,11,5,6,15,0,3,4,7,2,12,1,10,14,9],[10,6,9,0,12,11,7,13,15,1,3,14,5,2,8,4],[3,15,0,6,10,1,13,8,9,4,5,11,12,7,2,14]],
    [[2,12,4,1,7,10,11,6,8,5,3,15,13,0,14,9],[14,11,2,12,4,7,13,1,5,0,15,10,3,9,8,6],[4,2,1,11,10,13,7,8,15,9,12,5,6,3,0,14],[11,8,12,7,1,14,2,13,6,15,0,9,10,4,5,3]],
    [[12,1,10,15,9,2,6,8,0,13,3,4,14,7,5,11],[10,15,4,2,7,12,9,5,6,1,13,14,0,11,3,8],[9,14,15,5,2,8,12,3,7,0,4,10,1,13,11,6],[4,3,2,12,9,5,15,10,11,14,1,7,6,0,8,13]],
    [[4,11,2,14,15,0,8,13,3,12,9,7,5,10,6,1],[13,0,11,7,4,9,1,10,14,3,5,12,2,15,8,6],[1,4,11,13,12,3,7,14,10,15,6,8,0,5,9,2],[6,11,13,8,1,4,10,7,9,5,0,15,14,2,3,12]],
    [[13,2,8,4,6,15,11,1,10,9,3,14,5,0,12,7],[1,15,13,8,10,3,7,4,12,5,6,11,0,14,9,2],[7,11,4,1,9,12,14,2,0,6,10,13,15,3,5,8],[2,1,14,7,4,10,8,13,15,12,9,0,3,5,6,11]],
]
_P = [16, 7, 20, 21, 29, 12, 28, 17, 1, 15, 23, 26, 5, 18, 31, 10,
      2, 8, 24, 14, 32, 27, 3, 9, 19, 13, 30, 6, 22, 11, 4, 25]


def _permute(bits, table):
    return [bits[i - 1] for i in table]


def _bytes_to_bits(data):
    return [(byte >> i) & 1 for byte in data for i in range(7, -1, -1)]


def _bits_to_bytes(bits):
    out = bytearray()
    for i in range(0, len(bits), 8):
        byte = 0
        for b in bits[i:i + 8]:
            byte = (byte << 1) | b
        out.append(byte)
    return bytes(out)


def _generate_subkeys(key_bytes):
    key_bits = _permute(_bytes_to_bits(key_bytes), _PC1)
    c, d = key_bits[:28], key_bits[28:]
    subkeys = []
    for shift in _SHIFTS:
        c = c[shift:] + c[:shift]
        d = d[shift:] + d[:shift]
        subkeys.append(_permute(c + d, _PC2))
    return subkeys


def _des_block(block_bits, subkeys):
    bits = _permute(block_bits, _IP)
    left, right = bits[:32], bits[32:]
    for k in subkeys:
        expanded = _permute(right, _E)
        xored = [expanded[i] ^ k[i] for i in range(48)]
        s_out = []
        for i in range(8):
            chunk = xored[i * 6:(i + 1) * 6]
            row = (chunk[0] << 1) | chunk[5]
            col = (chunk[1] << 3) | (chunk[2] << 2) | (chunk[3] << 1) | chunk[4]
            val = _S_BOX[i][row][col]
            s_out.extend((val >> bit) & 1 for bit in range(3, -1, -1))
        f_out = _permute(s_out, _P)
        left, right = right, [left[i] ^ f_out[i] for i in range(32)]
    return _permute(right + left, _FP)


_DES_KEY = b"38346591"
_PURE_SUBKEYS = _generate_subkeys(_DES_KEY)[::-1]


def _pure_des_decrypt(cipher_bytes):
    plain = bytearray()
    for i in range(0, len(cipher_bytes) - 7, 8):
        plain.extend(_bits_to_bytes(_des_block(_bytes_to_bits(cipher_bytes[i:i + 8]), _PURE_SUBKEYS)))
    return bytes(plain)


QUALITY_SUFFIX = {"12": "_12", "48": "_48", "96": "_96", "160": "_160", "320": "_320"}


def decrypt_media_url(encrypted_url, quality="320"):
    """Decrypts JioSaavn encrypted_media_url into a direct CDN AAC/MP4 URL."""
    if not encrypted_url:
        return ""
    try:
        enc = encrypted_url.strip().replace("_", "/").replace("-", "+")
        enc += "=" * (-len(enc) % 4)
        raw = base64.b64decode(enc)
        if PYCRYPTO_AVAILABLE:
            dec = PyCryptoDES.new(_DES_KEY, PyCryptoDES.MODE_ECB).decrypt(raw)
        else:
            dec = _pure_des_decrypt(raw)
        url = dec.rstrip(bytes(range(0, 17))).decode("utf-8", errors="ignore").strip()
        if not url.startswith("http"):
            return ""
        url = url.replace("http://", "https://")
        suffix = QUALITY_SUFFIX.get(str(quality), "_320")
        return re.sub(r"_(12|48|96|160|320)\.mp4", f"{suffix}.mp4", url)
    except Exception as exc:
        print(f"[decrypt] {exc}")
        return ""


# ═══════════════════════════════════════════════════════════════════════════════
# TTL cache (serves stale data when JioSaavn is temporarily unreachable)
# ═══════════════════════════════════════════════════════════════════════════════
HOURLY = 3600
SHORT = 600
_CACHE = {}
_CACHE_LOCK = threading.Lock()
_CACHE_MAX = 800
_STREAM_CACHE = {}
_TRACK_CACHE = {}
_LAST_REFRESH = {"at": 0}


def cached(key, ttl, producer):
    now = time.time()
    hit = _CACHE.get(key)
    if hit and now - hit[0] < ttl:
        return hit[1]
    try:
        value = producer()
    except Exception as exc:
        print(f"[cache:{key}] {exc}")
        value = None
    if value:
        with _CACHE_LOCK:
            if len(_CACHE) >= _CACHE_MAX:
                for old_key, _ in sorted(_CACHE.items(), key=lambda kv: kv[1][0])[: _CACHE_MAX // 4]:
                    _CACHE.pop(old_key, None)
            _CACHE[key] = (now, value)
        return value
    return hit[1] if hit else value


def _remember(store, key, value, limit=5000):
    if len(store) >= limit:
        store.clear()
    store[key] = value


# ═══════════════════════════════════════════════════════════════════════════════
# Languages, moods & sessions (Indian content first)
# ═══════════════════════════════════════════════════════════════════════════════
INDIAN_LANGUAGES = [
    "hindi", "punjabi", "tamil", "telugu", "marathi", "gujarati", "bengali",
    "kannada", "malayalam", "bhojpuri", "haryanvi", "rajasthani", "odia", "assamese", "urdu",
]
SUPPORTED_LANGUAGES = INDIAN_LANGUAGES + ["english", "sanskrit"]
DEFAULT_LANGUAGES = ["hindi", "punjabi", "tamil", "telugu", "marathi", "gujarati", "bengali", "bhojpuri", "haryanvi"]
LANGUAGE_GROUPS = {
    "all": DEFAULT_LANGUAGES,
    "india": DEFAULT_LANGUAGES,
    "south": ["tamil", "telugu", "kannada", "malayalam"],
    "north": ["hindi", "punjabi", "haryanvi", "bhojpuri", "rajasthani"],
}

MOOD_QUERIES = {
    "devotional": ["Bhakti Songs", "Hanuman Chalisa", "Shiv Bhajan", "Krishna Bhajan", "Aarti Sangrah"],
    "romantic": ["Romantic Hindi Hits", "Love Songs Bollywood", "Arijit Singh Romantic", "Soulful Hindi Melodies"],
    "chill": ["Hindi Acoustic", "Lofi Hindi", "Bollywood Unplugged", "Late Night Hindi"],
    "lofi": ["Lofi Hindi", "Bollywood Lofi Flip", "Slowed Reverb Hindi"],
    "party": ["Bollywood Party Songs", "Punjabi Party Songs", "Dance Hits Hindi"],
    "workout": ["Workout Bollywood", "Gym Punjabi Songs", "High Energy Hindi"],
    "sad": ["Sad Hindi Songs", "Heartbreak Bollywood", "Emotional Hindi Songs"],
    "classics": ["Lata Mangeshkar Hits", "Kishore Kumar Classics", "Mohammad Rafi Hits", "RD Burman Hits"],
    "retro": ["90s Hindi Hits", "80s Bollywood Hits", "Old Hindi Songs"],
    "indie": ["Hindi Indie Hits", "Indian Indie Pop", "Hindi Rap Hits"],
    "garba": ["Garba Songs", "Navratri Dandiya Hits", "Gujarati Garba"],
    "ghazal": ["Ghazal Hits", "Jagjit Singh Ghazals", "Sufi Songs"],
}

SESSIONS = [
    {"id": "early_morning", "label": "Early Morning Bhakti", "start": 4, "end": 7,
     "queries": ["Morning Bhajan", "Suprabhatam", "Devotional Morning", "Gayatri Mantra"],
     "moods": ["devotional"]},
    {"id": "morning", "label": "Fresh Morning", "start": 7, "end": 11,
     "queries": ["Morning Fresh Hits", "Feel Good Hindi", "Good Morning Songs", "Happy Bollywood"],
     "moods": ["chill", "devotional"]},
    {"id": "afternoon", "label": "Afternoon Energy", "start": 11, "end": 16,
     "queries": ["Bollywood Hits", "Workout Hits", "Drive Songs", "Fresh Hits"],
     "moods": ["workout", "party"]},
    {"id": "evening", "label": "Evening Chai & Chill", "start": 16, "end": 20,
     "queries": ["Evening Chill", "Retro Evenings", "Monsoon Melodies", "Acoustic Love"],
     "moods": ["chill", "retro"]},
    {"id": "night", "label": "Romantic Night", "start": 20, "end": 24,
     "queries": ["Romantic Night", "Love Songs", "Party Hits", "Dance Hits"],
     "moods": ["romantic", "party"]},
    {"id": "late_night", "label": "Late Night Lofi", "start": 0, "end": 4,
     "queries": ["Late Night Lofi", "Sad Songs", "Sleep Songs", "Slowed Reverb"],
     "moods": ["lofi", "sad"]},
]

RADIO_STATIONS = [
    {"id": "air_vividh_bharati", "name": "AIR Vividh Bharati", "category": "Golden Era / Retro Classics",
     "stream_url": "https://air.pc.cdn.bitgravity.com/air/live/pbaudio001/playlist.m3u8",
     "description": "Immortal Bollywood classics & golden era memories from Akashvani Mumbai.",
     "bitrate": "192 kbps HD", "is_live": True},
    {"id": "air_fm_gold", "name": "AIR FM Gold Delhi", "category": "Retro Melodies & News",
     "stream_url": "https://airhlspush.pc.cdn.bitgravity.com/httppush/hlspbaudio005/hlspbaudio00564kbps.m3u8",
     "description": "National broadcast of timeless retro songs and midday melodies.",
     "bitrate": "192 kbps HD", "is_live": True},
    {"id": "hindi_gold_retro", "name": "Hindi Gold Classics 24/7", "category": "Evergreen Retro MP3",
     "stream_url": "https://azuracast.vibesounds.in:8010/radio.mp3",
     "description": "Non-stop Kishore Kumar, Lata Mangeshkar, and R.D. Burman gems.",
     "bitrate": "128 kbps", "is_live": True},
    {"id": "lofi_chill_live", "name": "Lo-Fi Chillhop Radio", "category": "Lo-Fi / Study & Focus",
     "stream_url": "https://streams.ilovemusic.de/iloveradio17.mp3",
     "description": "Peaceful lo-fi beats and chillhop 24/7.", "bitrate": "192 kbps HD", "is_live": True},
    {"id": "top_charts_live", "name": "Today Top Chartbusters", "category": "Trending Chart Hits",
     "stream_url": "https://streams.ilovemusic.de/iloveradio1.mp3",
     "description": "Non-stop trending chart hits and party beats.", "bitrate": "192 kbps HD", "is_live": True},
    {"id": "bhakti_sagar_live", "name": "Bhakti Sagar Divine Live", "category": "Devotional / Mantras",
     "stream_url": "http://millenniumhits.out.airtime.pro:8000/millenniumhits_a",
     "description": "Divine morning Bhajans, sacred mantras, and Aarti.", "bitrate": "128 kbps", "is_live": True},
    {"id": "classical_symphonies", "name": "Classical Symphonies Live", "category": "Classical & Instrumental",
     "stream_url": "https://stream.srg-ssr.ch/m/rsc_de/mp3_128",
     "description": "Timeless symphonies from Mozart, Beethoven, Chopin and Bach.", "bitrate": "128 kbps", "is_live": True},
    {"id": "indie_groove_live", "name": "SomaFM Indie Pop & Groove", "category": "Indie / Acoustic Groove",
     "stream_url": "https://ice1.somafm.com/groovesalad-128-mp3",
     "description": "Chilled ambient beats, grooves and indie pop.", "bitrate": "128 kbps", "is_live": True},
]


def parse_languages(raw):
    """'all' | 'south' | 'hindi' | 'hindi,punjabi' -> ordered list of JioSaavn languages."""
    value = (raw or "all").lower().strip()
    if value in LANGUAGE_GROUPS:
        return list(LANGUAGE_GROUPS[value])
    langs = [l.strip() for l in value.split(",") if l.strip() in SUPPORTED_LANGUAGES]
    return langs or list(DEFAULT_LANGUAGES)


def current_session(now=None):
    now = now or datetime.now(IST)
    hour = now.hour
    for session in SESSIONS:
        if session["start"] <= hour < session["end"]:
            return session
    return SESSIONS[0]


def language_rank(lang, preferred):
    lang = (lang or "").lower()
    if lang in preferred:
        return preferred.index(lang)
    if lang in INDIAN_LANGUAGES:
        return len(preferred) + INDIAN_LANGUAGES.index(lang)
    return 100


def prioritize_indian(items, preferred):
    """Stable sort: preferred languages first, then other Indian languages, then the rest."""
    return sorted(items, key=lambda it: language_rank(it.get("language"), preferred))


def interleave_languages(items, preferred):
    """
    Mixes preferred languages so a multi-language feed isn't a wall of one language:
    the first preferred language gets 2 slots per round, others 1, non-Indian content last.
    """
    if len(preferred) <= 1:
        return prioritize_indian(items, preferred)
    buckets = {lang: [] for lang in preferred}
    rest = []
    for it in items:
        lang = (it.get("language") or "").lower()
        (buckets[lang] if lang in buckets else rest).append(it)
    out = []
    while any(buckets.values()):
        for idx, lang in enumerate(preferred):
            take = 2 if idx == 0 else 1
            out.extend(buckets[lang][:take])
            buckets[lang] = buckets[lang][take:]
    return out + prioritize_indian(rest, preferred)


# ═══════════════════════════════════════════════════════════════════════════════
# JioSaavn network client
# ═══════════════════════════════════════════════════════════════════════════════
JIO_API = "https://www.jiosaavn.com/api.php"
_USER_AGENT = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
               "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36")


def jio_call(call, params=None, languages=None, ctx="web6dot0", api_version="4", timeout=12, retries=1):
    query = {"__call": call, "_format": "json", "_marker": "0", "ctx": ctx, "cc": "in"}
    if api_version:
        query["api_version"] = api_version
    query.update({k: v for k, v in (params or {}).items() if v is not None})
    url = f"{JIO_API}?{urllib.parse.urlencode(query)}"
    lang_cookie = urllib.parse.quote(",".join(languages or DEFAULT_LANGUAGES))
    headers = {
        "User-Agent": _USER_AGENT,
        "Accept": "application/json, text/plain, */*",
        "Accept-Language": "en-IN,en;q=0.9,hi;q=0.8",
        "Referer": "https://www.jiosaavn.com/",
        "Cookie": f"L={lang_cookie}; DL=english; gdpr_acceptance=true",
    }
    last_exc = None
    for _ in range(retries + 1):
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                raw = resp.read().decode("utf-8", errors="ignore").strip()
            if raw.startswith("/**/"):
                raw = raw[4:].strip()
            if raw.endswith(";"):
                raw = raw[:-1]
            return json.loads(raw) if raw else {}
        except Exception as exc:
            last_exc = exc
            time.sleep(0.3)
    print(f"[jio:{call}] {last_exc}")
    return {}


def _text(value):
    return html.unescape(str(value or "")).strip()


def _hi_res(url, size="500x500"):
    if not url:
        return ""
    url = str(url).replace("http://", "https://")
    return re.sub(r"\d{2,3}x\d{2,3}", size, url)


def _token_from_url(perma_url):
    if not perma_url:
        return ""
    return str(perma_url).rstrip("/").split("/")[-1]


def _int(value, default=0):
    try:
        return int(str(value).replace(",", ""))
    except (TypeError, ValueError):
        return default


def _artist_list(item, more):
    artist_map = more.get("artistMap") or item.get("artistMap") or {}
    artists = []
    if isinstance(artist_map, dict):
        for role in ("primary_artists", "featured_artists", "artists"):
            for a in artist_map.get(role) or []:
                if not isinstance(a, dict) or not a.get("name"):
                    continue
                if any(x["id"] == a.get("id") for x in artists):
                    continue
                artists.append({
                    "id": str(a.get("id") or ""),
                    "name": _text(a.get("name")),
                    "role": a.get("role") or role,
                    "image": _hi_res(a.get("image")),
                    "token": _token_from_url(a.get("perma_url")),
                })
    if not artists:
        names = item.get("primary_artists") or more.get("primary_artists") or item.get("singers") or ""
        ids = item.get("primary_artists_id") or more.get("primary_artists_id") or ""
        id_list = [i.strip() for i in str(ids).split(",")]
        for idx, name in enumerate([n.strip() for n in _text(names).split(",") if n.strip()]):
            artists.append({"id": id_list[idx] if idx < len(id_list) else "", "name": name,
                            "role": "primary_artists", "image": "", "token": ""})
    return artists


def format_track(item, quality="320"):
    """Normalises any JioSaavn song payload (api v4 or legacy) into the app's track shape."""
    if not isinstance(item, dict) or not item.get("id"):
        return {}
    tid = str(item["id"])
    more = item.get("more_info") or {}
    enc = more.get("encrypted_media_url") or item.get("encrypted_media_url") or ""
    stream_url = decrypt_media_url(enc, quality) if enc else ""
    if stream_url:
        _remember(_STREAM_CACHE, tid, stream_url)

    artists = _artist_list(item, more)
    primary = [a["name"] for a in artists if a["role"] == "primary_artists"] or [a["name"] for a in artists]
    artist_text = ", ".join(primary[:4])
    if not artist_text:
        subtitle = _text(item.get("subtitle"))
        artist_text = subtitle.split(" - ")[0] if subtitle else (_text(more.get("music")) or "Unknown Artist")

    image = _hi_res(item.get("image"))
    duration = _int(more.get("duration") or item.get("duration"))
    album_id = str(more.get("album_id") or item.get("albumid") or "")
    track = {
        "id": tid,
        "type": "song",
        "title": _text(item.get("title") or item.get("song")) or "Unknown Title",
        "artist": artist_text,
        "artists": artists,
        "album": _text(more.get("album") or item.get("album")) or "Single",
        "album_id": album_id,
        "album_token": _token_from_url(more.get("album_url") or item.get("album_url")),
        "artwork_url": image,
        "thumbnail": image,
        "image_small": _hi_res(item.get("image"), "150x150"),
        "duration": duration,
        "duration_ms": duration * 1000,
        "language": (item.get("language") or "").lower(),
        "year": str(item.get("year") or ""),
        "release_date": more.get("release_date") or item.get("release_date") or "",
        "label": _text(more.get("label") or item.get("label")),
        "play_count": _int(item.get("play_count")),
        "explicit": str(item.get("explicit_content") or "0") == "1",
        "has_lyrics": str(more.get("has_lyrics") or item.get("has_lyrics") or "false").lower() == "true",
        "is_320kbps": str(more.get("320kbps") or item.get("320kbps") or "false").lower() == "true",
        "perma_url": item.get("perma_url") or "",
        "token": _token_from_url(item.get("perma_url")),
        "stream_url": stream_url or f"/api/play/{tid}",
        "download_url": stream_url or f"/api/play/{tid}",
        "source": "jiosaavn",
    }
    if stream_url:
        _remember(_TRACK_CACHE, tid, track)
    return track


def format_entity(item):
    """Normalises albums / playlists / artists / radio / channels; songs go to format_track."""
    if not isinstance(item, dict):
        return {}
    kind = (item.get("type") or "").lower()
    if kind == "song":
        return format_track(item)
    more = item.get("more_info") or {}
    title = _text(item.get("title") or item.get("name") or item.get("listname"))
    if not title:
        return {}
    return {
        "id": str(item.get("id") or item.get("listid") or item.get("albumid") or item.get("artistId") or item.get("songid") or ""),
        "type": kind or "unknown",
        "title": title,
        "subtitle": _text(item.get("subtitle") or item.get("description") or more.get("description")),
        "image": _hi_res(item.get("image")),
        "artwork_url": _hi_res(item.get("image")),
        "language": (item.get("language") or more.get("language") or "").lower(),
        "year": str(item.get("year") or more.get("year") or ""),
        "song_count": _int(more.get("song_count") or item.get("count") or item.get("list_count")),
        "follower_count": _int(more.get("follower_count") or item.get("follower_count")),
        "owner": more.get("firstname") or "",
        "is_editorial": (more.get("firstname") or "").lower() == "jiosaavn",
        "perma_url": item.get("perma_url") or "",
        "token": _token_from_url(item.get("perma_url")),
        "source": "jiosaavn",
    }


def dedupe(items, exclude_ids=None, exclude_titles=None):
    seen_ids = set(exclude_ids or [])
    seen_titles = set(exclude_titles or [])
    out = []
    for it in items:
        if not it or not it.get("id") or it["id"] in seen_ids:
            continue
        norm = normalize_title(it.get("title", "")) if it.get("type") == "song" else ""
        if norm and norm in seen_titles:
            continue
        seen_ids.add(it["id"])
        if norm:
            seen_titles.add(norm)
        out.append(it)
    return out


def normalize_title(title):
    t = (title or "").lower()
    t = re.sub(r"\(.*?\)|\[.*?\]", "", t)
    t = t.split(" - ")[0]
    t = re.sub(r"\b(remix|lofi|lo-fi|slowed|reverb|acoustic|version|unplugged|reprise|female|male|duet|sad|"
               r"feat|ft|official|audio|video|from|eclipsa)\b", "", t)
    t = re.sub(r"[^\w\s]", "", t)
    return " ".join(t.split())


def _tracks(items):
    return [t for t in (format_track(i) for i in items or []) if t]


def _entities(items, allowed=None):
    out = []
    for i in items or []:
        e = format_entity(i)
        if e and (not allowed or e.get("type") in allowed):
            out.append(e)
    return out


# ─── Catalog operations ─────────────────────────────────────────────────────────
def search_songs(query, limit=20, page=1, languages=None):
    data = jio_call("search.getResults", {"q": query, "p": page, "n": limit}, languages)
    return dedupe(_tracks(data.get("results") if isinstance(data, dict) else []))


def search_entities(kind, query, limit=20, page=1, languages=None):
    call = {"albums": "search.getAlbumResults", "artists": "search.getArtistResults",
            "playlists": "search.getPlaylistResults"}[kind]
    data = jio_call(call, {"q": query, "p": page, "n": limit}, languages)
    results = data.get("results") if isinstance(data, dict) else []
    return {"total": _int(data.get("total")) if isinstance(data, dict) else 0, "results": _entities(results)}


def autocomplete(query, languages=None):
    data = jio_call("autocomplete.get", {"query": query}, languages)
    if not isinstance(data, dict):
        return {}
    out = {}
    for key in ("topquery", "songs", "albums", "artists", "playlists"):
        block = data.get(key) or {}
        out[key] = {"position": block.get("position", 99), "items": _entities(block.get("data"))}
    return out


def song_details(song_id, quality="320"):
    if quality == "320" and song_id in _TRACK_CACHE:
        return _TRACK_CACHE[song_id]
    data = jio_call("song.getDetails", {"pids": song_id})
    songs = data.get("songs") if isinstance(data, dict) else None
    item = songs[0] if songs else (data.get(song_id) if isinstance(data, dict) else None)
    return format_track(item, quality) if item else {}


def resolve_stream(song_id, quality="320"):
    if quality == "320" and song_id in _STREAM_CACHE:
        return _STREAM_CACHE[song_id]
    track = song_details(song_id, quality)
    url = track.get("stream_url", "")
    return url if url.startswith("http") else ""


def entity_details(kind, entity_id=None, token=None, limit=50, page=1, languages=None):
    """Album / playlist details by numeric id or by perma_url token."""
    if token:
        data = jio_call("webapi.get", {"token": token, "type": kind, "n": limit, "p": page}, languages)
    elif kind == "album":
        data = jio_call("content.getAlbumDetails", {"albumid": entity_id}, languages)
    else:
        data = jio_call("playlist.getDetails", {"listid": entity_id, "n": limit, "p": page}, languages)
    if not isinstance(data, dict) or not data.get("id"):
        return {}
    info = format_entity({**data, "type": kind})
    more = data.get("more_info") or {}
    info.update({
        "description": _text(data.get("header_desc") or more.get("description")),
        "song_count": _int(data.get("list_count") or more.get("song_count")),
        "artists": _artist_list(data, more),
        "tracks": dedupe(_tracks(data.get("list"))),
        "page": page,
    })
    return info


def artist_details(artist_id=None, token=None, n_song=30, n_album=20, languages=None):
    if token:
        data = jio_call("webapi.get", {"token": token, "type": "artist", "n_song": n_song,
                                       "n_album": n_album}, languages)
    else:
        data = jio_call("artist.getArtistPageDetails", {"artistId": artist_id, "n_song": n_song,
                                                        "n_album": n_album, "page": 0,
                                                        "category": "", "sort_order": ""}, languages)
    if not isinstance(data, dict) or not data.get("name"):
        return {}
    bio = data.get("bio")
    try:
        bio = json.loads(bio) if isinstance(bio, str) and bio.startswith("[") else bio
    except ValueError:
        pass
    return {
        "id": str(data.get("artistId") or artist_id or ""),
        "type": "artist",
        "name": _text(data.get("name")),
        "subtitle": _text(data.get("subtitle")),
        "image": _hi_res(data.get("image")),
        "follower_count": _int(data.get("follower_count")),
        "fan_count": data.get("fan_count") or "",
        "is_verified": bool(data.get("isVerified")),
        "dominant_language": data.get("dominantLanguage") or "",
        "dominant_type": data.get("dominantType") or "",
        "available_languages": data.get("availableLanguages") or [],
        "bio": bio or [],
        "dob": data.get("dob") or "",
        "top_songs": dedupe(_tracks(data.get("topSongs"))),
        "top_albums": _entities(data.get("topAlbums")),
        "singles": _entities(data.get("singles")),
        "latest_release": _entities(data.get("latest_release")),
        "dedicated_playlists": _entities(data.get("dedicated_artist_playlist")),
        "featured_playlists": _entities(data.get("featured_artist_playlist")),
        "similar_artists": _entities([{**a, "type": "artist"} for a in data.get("similarArtists") or []]),
        "source": "jiosaavn",
    }


def artist_songs(artist_id, page=1, sort="latest", languages=None):
    data = jio_call("artist.getArtistMoreSong", {"artistId": artist_id, "page": max(page - 1, 0),
                                                 "category": sort, "sort_order": "desc"}, languages)
    block = data.get("topSongs") if isinstance(data, dict) else {}
    songs = block.get("songs") if isinstance(block, dict) else block
    return {"total": _int(block.get("total")) if isinstance(block, dict) else 0,
            "tracks": dedupe(_tracks(songs))}


def lyrics(song_id):
    data = jio_call("lyrics.getLyrics", {"lyrics_id": song_id})
    if not isinstance(data, dict) or not data.get("lyrics"):
        return {}
    return {"id": song_id, "lyrics": _text(data["lyrics"]).replace("<br>", "\n"),
            "copyright": _text(data.get("lyrics_copyright")), "snippet": _text(data.get("snippet"))}


# ─── Live discovery (hourly cached) ─────────────────────────────────────────────
def _lang_key(languages):
    return ",".join(languages)


def live_trending(languages):
    def produce():
        primary = (languages[0] if languages else "hindi").lower()
        is_single_region = len(languages) == 1 and primary not in ("all", "india")

        with ThreadPoolExecutor(max_workers=4) as pool:
            futures = [pool.submit(jio_call, "content.getTrending",
                                   {"entity_type": "song", "entity_language": lang}, [lang])
                       for lang in languages[:4]]
            buckets = [f.result() for f in futures]
        songs = []
        for bucket in buckets:
            songs.extend(_tracks(bucket if isinstance(bucket, list) else []))

        if is_single_region:
            regional = [s for s in songs if (s.get("language") or "").lower() == primary]
            if len(regional) < 15:
                more = search_songs(f"Trending {primary} songs", 30, 1, languages)
                regional.extend([s for s in more if (s.get("language") or "").lower() == primary])
            return dedupe(regional) if regional else prioritize_indian(dedupe(songs), languages)

        if len(songs) < 10:
            songs.extend(search_songs(f"Trending {primary} songs", 30, 1, languages))
        return prioritize_indian(dedupe(songs), languages)
    return cached(f"trending:{_lang_key(languages)}", HOURLY, produce) or []


def live_new_releases(languages, page=1, limit=30):
    def produce():
        data = jio_call("content.getAlbums", {"n": limit, "p": page}, languages)
        items = data.get("data") if isinstance(data, dict) else []
        return prioritize_indian(_entities(items), languages)
    return cached(f"new:{_lang_key(languages)}:{page}:{limit}", HOURLY, produce) or []


def live_charts(languages):
    def produce():
        data = jio_call("content.getCharts", {"n": 30}, languages)
        return _entities(data if isinstance(data, list) else [])
    return cached(f"charts:{_lang_key(languages)}", HOURLY, produce) or []


def live_featured_playlists(languages, page=1, limit=30):
    def produce():
        data = jio_call("content.getFeaturedPlaylists", {"n": limit, "p": page}, languages)
        return _entities(data.get("data") if isinstance(data, dict) else [])
    return cached(f"featured:{_lang_key(languages)}:{page}:{limit}", HOURLY, produce) or []


_HOME_SKIP_TYPES = {"show", "episode", "season"}


def live_home(languages):
    def produce():
        data = jio_call("webapi.getLaunchData", {}, languages)
        if not isinstance(data, dict):
            return {}
        modules = data.get("modules") or {}
        sections = []
        for key, meta in sorted(modules.items(), key=lambda kv: _int(kv[1].get("position"), 99)):
            raw_items = data.get(key)
            if not isinstance(raw_items, list):
                continue
            items = [e for e in (format_entity(i) for i in raw_items) if e and e.get("type") not in _HOME_SKIP_TYPES]
            if not items:
                continue
            sections.append({
                "key": key.replace("promo:vx:data:", "promo_"),
                "title": _text(meta.get("title")),
                "subtitle": _text(meta.get("subtitle")),
                "position": _int(meta.get("position"), 99),
                "items": items,
            })
        genres = [e for e in (format_entity(i) for i in data.get("browse_discover") or []) if e]
        return {"sections": sections, "genres": genres}
    return cached(f"home:{_lang_key(languages)}", HOURLY, produce) or {"sections": [], "genres": []}


def playlist_tracks_for(query, languages, limit=40):
    """Finds the best live JioSaavn playlist for a query (editorial first) and returns it with tracks."""
    found = search_entities("playlists", query, 10, 1, languages)["results"]
    if not found:
        return {}
    found.sort(key=lambda p: (not p.get("is_editorial"), -p.get("follower_count", 0)))
    for candidate in found[:3]:
        details = entity_details("playlist", entity_id=candidate["id"], limit=limit, languages=languages)
        if details.get("tracks"):
            return details
    return {}


def trending_pool(languages):
    """Trending + top chart songs + latest release songs, merged & Indian-prioritised."""
    def produce():
        primary = (languages[0] if languages else "hindi").lower()
        is_single_region = len(languages) == 1 and primary not in ("all", "india")

        pool = list(live_trending(languages))
        charts = live_charts(languages)
        if charts:
            target_chart = None
            if is_single_region:
                for c in charts:
                    t_lower = (c.get("title") or "").lower()
                    l_lower = (c.get("language") or "").lower()
                    if primary in t_lower or primary == l_lower:
                        target_chart = c
                        break
            if not target_chart:
                target_chart = charts[0]
            chart_id = target_chart.get("id") or target_chart.get("listid")
            if chart_id:
                top_chart = entity_details("playlist", entity_id=chart_id, limit=50, languages=languages)
                chart_tracks = top_chart.get("tracks", [])
                if is_single_region:
                    chart_tracks = [t for t in chart_tracks if (t.get("language") or "").lower() == primary]
                pool.extend(chart_tracks)

        new_songs = [e for e in live_new_releases(languages) if e.get("type") == "song"]
        pool.extend(new_songs)

        if is_single_region:
            lang_pool = [t for t in pool if (t.get("language") or "").lower() == primary]
            if len(lang_pool) < 20:
                more = search_songs(f"Top {primary} Songs", 30, 1, languages)
                lang_pool.extend([t for t in more if (t.get("language") or "").lower() == primary])
            if lang_pool:
                return dedupe(lang_pool)
            return dedupe(pool)

        return interleave_languages(dedupe(pool), languages)
    return cached(f"pool:{_lang_key(languages)}", HOURLY, produce) or []


def mood_tracks(mood, languages, page=1, limit=20):
    queries = MOOD_QUERIES.get(mood) or [mood]
    primary = (languages[0] if languages else "hindi").lower()

    if primary not in ("hindi", "all", "india"):
        p_title = primary.capitalize()
        queries = [q.replace("Hindi", p_title).replace("Bollywood", p_title) for q in queries]

    query = queries[(page - 1) % len(queries)]
    inner_page = (page - 1) // len(queries) + 1
    key = f"mood:{mood}:{_lang_key(languages)}:{page}:{limit}"

    def produce():
        tracks = search_songs(query, limit, inner_page, languages)
        if primary not in ("all", "india"):
            matching = [t for t in tracks if (t.get("language") or "").lower() == primary]
            rest = [t for t in tracks if (t.get("language") or "").lower() != primary]
            return matching + rest
        return tracks

    return cached(key, HOURLY, produce) or [], query


def session_playlists(languages, session=None, limit_tracks=30):
    session = session or current_session()
    primary = languages[0]
    hour_bucket = datetime.now(IST).strftime("%Y%m%d%H")

    def produce():
        queries = [f"{q} {primary}" if primary != "hindi" else q for q in session["queries"]]
        with ThreadPoolExecutor(max_workers=4) as pool:
            results = list(pool.map(lambda q: search_entities("playlists", q, 6, 1, languages)["results"], queries))
        playlists = []
        for res in results:
            res.sort(key=lambda p: (not p.get("is_editorial"), -p.get("follower_count", 0)))
            playlists.extend(res[:3])
        playlists = dedupe(playlists)
        featured = None
        if playlists:
            featured = entity_details("playlist", entity_id=playlists[0]["id"], limit=limit_tracks, languages=languages)
        return {"playlists": playlists, "featured": featured or {}}
    data = cached(f"session:{session['id']}:{_lang_key(languages)}:{hour_bucket}", HOURLY, produce) or {}
    return {
        "session": {k: session[k] for k in ("id", "label", "start", "end", "moods")},
        "timezone": "Asia/Kolkata",
        "local_time": datetime.now(IST).strftime("%H:%M"),
        "playlists": data.get("playlists", []),
        "featured": data.get("featured", {}),
    }


# ─── Suggestion / "up next" logic ───────────────────────────────────────────────
def related_tracks(song_id, title="", artist="", limit=15, exclude=None, languages=None):
    """
    Smart queue built from several live signals, never repeating the current
    song or recently played ones:
      1. JioSaavn's own recommendation engine (reco.getreco)
      2. Top songs of the same primary artist (artist page)
      3. Trending songs in the same language
      4. Search fallback on artist / title
    A per-artist cap keeps the queue diverse.
    """
    exclude_ids = set(exclude or [])
    seed = {}
    if song_id:
        exclude_ids.add(song_id)
        seed = song_details(song_id)
    elif title or artist:
        found = search_songs(f"{title} {artist}".strip(), 1, 1, languages)
        if found:
            seed = found[0]
            exclude_ids.add(seed["id"])
    exclude_titles = {normalize_title(seed.get("title") or title)} - {""}

    seed_lang = seed.get("language") or ""
    langs = ([seed_lang] if seed_lang in SUPPORTED_LANGUAGES else []) + [l for l in (languages or DEFAULT_LANGUAGES) if l != seed_lang]
    primary_artist = next((a for a in seed.get("artists", []) if a.get("role") == "primary_artists" and a.get("id")), None)

    def from_reco():
        if not seed.get("id"):
            return []
        data = jio_call("reco.getreco", {"pid": seed["id"], "language": seed_lang or None}, langs, ctx="android")
        items = []
        if isinstance(data, dict):
            for value in data.values():
                if isinstance(value, list):
                    items.extend(value)
        elif isinstance(data, list):
            items = data
        return _tracks(items)

    def from_artist():
        if not primary_artist:
            return []
        return artist_details(artist_id=primary_artist["id"], n_song=20, n_album=0, languages=langs).get("top_songs", [])

    def from_language():
        return live_trending(langs[:2])

    def from_search():
        name = (primary_artist or {}).get("name") or (artist.split(",")[0].strip() if artist else "") or title
        fallback = f"Top {seed_lang} Hits" if seed_lang else "Top Indian Hits"
        return search_songs(name or fallback, 20, 1, langs)

    with ThreadPoolExecutor(max_workers=4) as pool:
        reco_f, artist_f, lang_f, search_f = (pool.submit(f) for f in (from_reco, from_artist, from_language, from_search))
        reco, by_artist, by_lang, by_search = reco_f.result(), artist_f.result(), lang_f.result(), search_f.result()

    merged = []
    for i in range(max(len(reco), len(by_artist), len(by_lang), len(by_search))):
        merged.extend(reco[2 * i:2 * i + 2])
        for bucket in (by_artist, by_lang, by_search):
            if i < len(bucket):
                merged.append(bucket[i])
    unique = dedupe(merged, exclude_ids=exclude_ids, exclude_titles=exclude_titles)
    if seed_lang:
        unique.sort(key=lambda t: 0 if (t.get("language") or "").lower() == seed_lang.lower() else 1)

    per_artist_cap = max(3, limit // 4)
    counts, queue, overflow = {}, [], []
    for track in unique:
        key = (track.get("artist") or "").split(",")[0].strip().lower()
        if counts.get(key, 0) < per_artist_cap:
            counts[key] = counts.get(key, 0) + 1
            queue.append(track)
        else:
            overflow.append(track)
        if len(queue) >= limit:
            break
    if len(queue) < limit:
        queue.extend(overflow[: limit - len(queue)])
    return seed, queue[:limit]


# ═══════════════════════════════════════════════════════════════════════════════
# Optional Spotify India new-release discovery (SPOTIFY_CLIENT_ID / SECRET)
# ═══════════════════════════════════════════════════════════════════════════════
_SPOTIFY_TOKEN = {"value": "", "expires": 0}


def spotify_enabled():
    return bool(os.environ.get("SPOTIFY_CLIENT_ID") and os.environ.get("SPOTIFY_CLIENT_SECRET"))


def _spotify_token():
    if _SPOTIFY_TOKEN["value"] and time.time() < _SPOTIFY_TOKEN["expires"] - 60:
        return _SPOTIFY_TOKEN["value"]
    creds = f"{os.environ['SPOTIFY_CLIENT_ID']}:{os.environ['SPOTIFY_CLIENT_SECRET']}"
    req = urllib.request.Request(
        "https://accounts.spotify.com/api/token",
        data=b"grant_type=client_credentials",
        headers={"Authorization": "Basic " + base64.b64encode(creds.encode()).decode(),
                 "Content-Type": "application/x-www-form-urlencoded"},
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        payload = json.loads(resp.read().decode())
    _SPOTIFY_TOKEN.update(value=payload["access_token"], expires=time.time() + int(payload.get("expires_in", 3600)))
    return _SPOTIFY_TOKEN["value"]


def spotify_new_releases_india(limit=20):
    """Spotify IN new releases, each resolved to a playable JioSaavn track (hourly cached)."""
    if not spotify_enabled():
        return []

    def produce():
        req = urllib.request.Request(
            f"https://api.spotify.com/v1/browse/new-releases?country=IN&limit={limit}",
            headers={"Authorization": f"Bearer {_spotify_token()}"},
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            albums = json.loads(resp.read().decode()).get("albums", {}).get("items", [])

        def resolve(album):
            artist = (album.get("artists") or [{}])[0].get("name", "")
            hits = search_songs(f"{album.get('name', '')} {artist}".strip(), 3, 1)
            if not hits:
                return None
            hit = dict(hits[0])
            hit["spotify"] = {"album": album.get("name"), "artist": artist,
                              "release_date": album.get("release_date"),
                              "url": (album.get("external_urls") or {}).get("spotify")}
            return hit

        with ThreadPoolExecutor(max_workers=6) as pool:
            resolved = [t for t in pool.map(resolve, albums) if t]
        return dedupe(resolved)
    return cached(f"spotify:new:{limit}", HOURLY, produce) or []


# ═══════════════════════════════════════════════════════════════════════════════
# Background hourly refresh (long-running hosts only; Vercel uses lazy TTL cache)
# ═══════════════════════════════════════════════════════════════════════════════
def refresh_catalog():
    started = time.time()
    for key in [k for k in _CACHE if k.split(":")[0] in ("trending", "new", "charts", "featured", "home", "pool", "session", "spotify")]:
        _CACHE.pop(key, None)
    groups = [DEFAULT_LANGUAGES, ["hindi"], ["punjabi"], LANGUAGE_GROUPS["south"]]
    for langs in groups:
        live_home(langs)
        trending_pool(langs)
        live_featured_playlists(langs)
        session_playlists(langs)
    spotify_new_releases_india()
    _LAST_REFRESH["at"] = int(time.time())
    return round(time.time() - started, 2)


def _hourly_refresher():
    time.sleep(5)
    while True:
        try:
            took = refresh_catalog()
            print(f"[refresh] catalog refreshed in {took}s")
        except Exception as exc:
            print(f"[refresh] {exc}")
        time.sleep(HOURLY)


def _keep_alive():
    base = os.environ.get("RENDER_EXTERNAL_URL", "").rstrip("/")
    if not base:
        return
    while True:
        time.sleep(600)
        try:
            req = urllib.request.Request(f"{base}/keepalive", headers={"User-Agent": "KeepAlive/1.0"})
            with urllib.request.urlopen(req, timeout=15):
                pass
        except Exception:
            pass


# ═══════════════════════════════════════════════════════════════════════════════
# Flask app
# ═══════════════════════════════════════════════════════════════════════════════
app = Flask(__name__, template_folder=os.path.join(BASE_DIR, "templates"))
CORS(app)

DOWNLOAD_FOLDER = os.path.join(tempfile.gettempdir(), "kalpkrut-downloads") if IS_VERCEL else os.path.join(BASE_DIR, "static")
COOKIES_FILE = os.path.join(BASE_DIR, "cookies.txt")
os.makedirs(DOWNLOAD_FOLDER, exist_ok=True)


def arg_int(name, default, minimum=1, maximum=100, *aliases):
    for key in (name, *aliases):
        raw = request.args.get(key)
        if raw not in (None, ""):
            try:
                return max(minimum, min(maximum, int(raw)))
            except ValueError:
                break
    return default


def req_languages():
    return parse_languages(request.args.get("lang") or request.args.get("language"))


def ok(payload, cache_seconds=300):
    resp = jsonify(payload)
    resp.headers["Cache-Control"] = (f"public, max-age=60, s-maxage={cache_seconds}, stale-while-revalidate=3600"
                                     if cache_seconds else "no-store")
    return resp


def not_found(message):
    resp = jsonify({"error": message})
    resp.status_code = 404
    resp.headers["Cache-Control"] = "no-store"
    return resp


@app.after_request
def security_headers(response):
    response.headers.setdefault("X-Content-Type-Options", "nosniff")
    response.headers.setdefault("Referrer-Policy", "strict-origin-when-cross-origin")
    response.headers.setdefault("Cache-Control", "no-store")
    return response


# ─── Meta ───────────────────────────────────────────────────────────────────────
@app.route("/")
def home():
    if os.path.exists(os.path.join(BASE_DIR, "templates", "index.html")):
        return render_template("index.html")
    return api_index()


@app.route("/api")
@app.route("/api/")
def api_index():
    return ok({
        "service": SERVICE_NAME,
        "version": VERSION,
        "status": "online",
        "endpoints": {
            "home": "/api/home?lang=all",
            "trending": "/api/trending?lang=hindi&page=1&limit=20",
            "new_releases": "/api/new-releases?lang=punjabi",
            "charts": "/api/charts?lang=tamil",
            "featured_playlists": "/api/playlists/featured?lang=all",
            "session": "/api/session?lang=hindi",
            "categories": "/api/categories",
            "category": "/api/category/romantic?lang=hindi",
            "search_songs": "/api/search?q=arijit",
            "search_all": "/api/search/all?q=arijit",
            "search_albums_artists_playlists": "/api/search/{albums|artists|playlists}?q=...",
            "suggest": "/api/suggest?q=kes",
            "song": "/api/track/{id}",
            "play": "/api/play/{id}?quality=320",
            "lyrics": "/api/lyrics/{id}",
            "album": "/api/album/{id} or /api/album?token=...",
            "playlist": "/api/playlist/{id} or /api/playlist?token=...",
            "artist": "/api/artist/{id} or /api/artist?token=...",
            "artist_songs": "/api/artist/{id}/songs?page=1&sort=latest|alphabetical|popularity",
            "related": "/api/related?id={songId}&exclude=id1,id2",
            "spotify_new_india": "/api/spotify/new-releases",
            "radio": "/api/radio/stations",
            "youtube": "/stream?url=..., /search?q=..., /download?url=...&type=audio",
        },
    }, 3600)


@app.route("/health")
@app.route("/keepalive")
def health_check():
    return ok({
        "status": "online",
        "service": SERVICE_NAME,
        "version": VERSION,
        "message": "Server is alive!",
        "crypto_engine": "PyCryptodome" if PYCRYPTO_AVAILABLE else "Pure-Python DES (Built-in)",
        "youtube": YTDLP_AVAILABLE,
        "spotify": spotify_enabled(),
        "runtime": "vercel" if IS_VERCEL else "server",
        "cached_entries": len(_CACHE),
        "cached_streams": len(_STREAM_CACHE),
        "last_refresh": _LAST_REFRESH["at"],
        "session": current_session()["id"],
    }, 0)


# ─── Discovery ──────────────────────────────────────────────────────────────────
@app.route("/api/home")
def api_home():
    languages = req_languages()
    with ThreadPoolExecutor(max_workers=3) as pool:
        home_f = pool.submit(live_home, languages)
        session_f = pool.submit(session_playlists, languages)
        spotify_f = pool.submit(spotify_new_releases_india) if spotify_enabled() else None
        home_data, session_data = home_f.result(), session_f.result()
        spotify_tracks = spotify_f.result() if spotify_f else []
    sections = list(home_data.get("sections", []))
    if session_data.get("playlists"):
        sections.insert(0, {"key": "session", "title": session_data["session"]["label"],
                            "subtitle": f"Picked for {session_data['local_time']} IST", "position": 0,
                            "items": session_data["playlists"]})
    if spotify_tracks:
        sections.insert(1, {"key": "spotify_new_india", "title": "New in India (Spotify)",
                            "subtitle": "Fresh releases, playable now", "position": 0, "items": spotify_tracks})
    return ok({"languages": languages, "session": session_data["session"], "sections": sections,
               "updated_at": int(time.time())})


@app.route("/api/trending")
def api_trending():
    languages = req_languages()
    limit = arg_int("limit", 20, 1, 50)
    page = arg_int("page", 1, 1, 500, "p")
    lang_raw = (request.args.get("lang") or request.args.get("language") or "all").lower().strip()

    if lang_raw in MOOD_QUERIES:
        tracks, query = mood_tracks(lang_raw, DEFAULT_LANGUAGES, page, limit)
        return ok({"tracks": tracks, "total": len(tracks), "page": page, "language": lang_raw,
                   "query": query, "source": "jiosaavn"})

    pool = trending_pool(languages)
    start = (page - 1) * limit
    tracks = pool[start:start + limit]
    query = "live_trending"
    if len(tracks) < limit:
        extra_page = max(1, page - len(pool) // max(limit, 1))
        session = current_session()
        moods = session["moods"] + ["romantic", "party", "chill"]
        mood = moods[extra_page % len(moods)]
        extra, query = mood_tracks(mood, languages, extra_page, limit)
        tracks = dedupe(tracks + extra, exclude_ids={t["id"] for t in pool[:start]})[:limit]
    return ok({"tracks": tracks, "total": max(len(pool), 100), "pool_size": len(pool), "page": page,
               "language": lang_raw, "languages": languages, "query": query, "source": "jiosaavn"})


@app.route("/api/new-releases")
@app.route("/api/new")
def api_new_releases():
    languages = req_languages()
    page = arg_int("page", 1, 1, 50, "p")
    limit = arg_int("limit", 30, 1, 50)
    primary = (languages[0] if languages else "hindi").lower()
    items = live_new_releases(languages, page, limit)
    tracks = [i for i in items if i.get("type") == "song"]
    if not tracks:
        query = f"Latest {primary.capitalize()} Songs" if primary not in ("all", "india") else "Latest Hindi Songs"
        tracks = search_songs(query, limit, page, languages)
    return ok({"items": items, "tracks": tracks,
               "albums": [i for i in items if i.get("type") == "album"],
               "page": page, "total": max(len(tracks), 100), "languages": languages, "source": "jiosaavn"})


@app.route("/api/charts")
def api_charts():
    languages = req_languages()
    return ok({"charts": live_charts(languages), "languages": languages, "source": "jiosaavn"})


@app.route("/api/playlists/featured")
@app.route("/api/playlists")
def api_featured_playlists():
    languages = req_languages()
    page = arg_int("page", 1, 1, 50, "p")
    limit = arg_int("limit", 30, 1, 50)
    return ok({"playlists": live_featured_playlists(languages, page, limit), "page": page,
               "languages": languages, "source": "jiosaavn"})


@app.route("/api/session")
def api_session():
    languages = req_languages()
    session_id = request.args.get("session")
    session = next((s for s in SESSIONS if s["id"] == session_id), None)
    return ok(session_playlists(languages, session), 600)


@app.route("/api/categories")
def api_categories():
    languages = req_languages()
    discover = live_home(languages).get("genres", [])
    return ok({
        "languages": [{"id": l, "name": l.title(), "indian": l in INDIAN_LANGUAGES} for l in SUPPORTED_LANGUAGES],
        "language_groups": LANGUAGE_GROUPS,
        "moods": [{"id": m, "name": m.title()} for m in MOOD_QUERIES],
        "sessions": [{k: s[k] for k in ("id", "label", "start", "end")} for s in SESSIONS],
        "current_session": current_session()["id"],
        "jiosaavn_genres": discover,
    }, 3600)


@app.route("/api/category/<name>")
def api_category(name):
    languages = req_languages()
    name = name.strip().lower()
    page = arg_int("page", 1, 1, 200, "p")
    limit = arg_int("limit", 20, 1, 50)
    if name in SUPPORTED_LANGUAGES or name in LANGUAGE_GROUPS:
        langs = parse_languages(name)
        pool = trending_pool(langs)
        start = (page - 1) * limit
        return ok({"category": name, "type": "language", "tracks": pool[start:start + limit],
                   "playlists": live_featured_playlists(langs, 1, 12) if page == 1 else [],
                   "page": page})
    tracks, query = mood_tracks(name, languages, page, limit)
    playlist = cached(f"catpl:{name}:{_lang_key(languages)}", HOURLY,
                      lambda: playlist_tracks_for(name, languages)) if page == 1 else {}
    return ok({"category": name, "type": "mood", "query": query, "tracks": tracks,
               "playlist": playlist or {}, "page": page})


@app.route("/api/spotify/new-releases")
def api_spotify_new():
    if not spotify_enabled():
        return ok({"enabled": False, "tracks": [],
                   "message": "Set SPOTIFY_CLIENT_ID and SPOTIFY_CLIENT_SECRET to enable."}, 0)
    tracks = spotify_new_releases_india(arg_int("limit", 20, 1, 50))
    return ok({"enabled": True, "tracks": tracks, "total": len(tracks), "source": "spotify+jiosaavn"})


@app.route("/api/refresh", methods=["GET", "POST"])
def api_refresh():
    secret = os.environ.get("CRON_SECRET")
    if secret and request.headers.get("Authorization") != f"Bearer {secret}":
        return jsonify({"error": "Unauthorized"}), 401
    return ok({"refreshed": True, "seconds": refresh_catalog(), "at": _LAST_REFRESH["at"]}, 0)


# ─── Search & suggestions ───────────────────────────────────────────────────────
@app.route("/api/search")
@app.route("/jiosaavn/search")
def api_search():
    query = (request.args.get("q") or request.args.get("query") or "").strip()
    limit = arg_int("limit", 20, 1, 50, "n")
    page = arg_int("page", 1, 1, 100, "p")
    if not query:
        return ok({"tracks": [], "total": 0, "source": "jiosaavn"}, 0)
    languages = req_languages()
    tracks = cached(f"search:{query.lower()}:{page}:{limit}:{_lang_key(languages)}", SHORT,
                    lambda: search_songs(query, limit, page, languages)) or []
    return ok({"tracks": tracks, "total": len(tracks), "page": page, "query": query, "source": "jiosaavn"}, 600)


@app.route("/api/search/all")
def api_search_all():
    query = (request.args.get("q") or request.args.get("query") or "").strip()
    if not query:
        return ok({"query": "", "results": {}}, 0)
    languages = req_languages()
    with ThreadPoolExecutor(max_workers=2) as pool:
        auto_f = pool.submit(autocomplete, query, languages)
        songs_f = pool.submit(search_songs, query, 10, 1, languages)
        auto, songs = auto_f.result(), songs_f.result()
    if songs:
        auto["songs"] = {"position": (auto.get("songs") or {}).get("position", 1), "items": songs}
    return ok({"query": query, "results": auto, "source": "jiosaavn"}, 600)


@app.route("/api/search/<kind>")
def api_search_kind(kind):
    if kind not in ("albums", "artists", "playlists", "songs"):
        return not_found("Unknown search type")
    query = (request.args.get("q") or request.args.get("query") or "").strip()
    limit = arg_int("limit", 20, 1, 50, "n")
    page = arg_int("page", 1, 1, 100, "p")
    if not query:
        return ok({"results": [], "total": 0}, 0)
    languages = req_languages()
    if kind == "songs":
        songs = search_songs(query, limit, page, languages)
        return ok({"results": songs, "tracks": songs, "total": len(songs), "page": page}, 600)
    data = search_entities(kind, query, limit, page, languages)
    return ok({**data, "page": page, "query": query, "type": kind}, 600)


@app.route("/api/suggest")
@app.route("/api/autocomplete")
def api_suggest():
    query = (request.args.get("q") or request.args.get("query") or "").strip()
    if len(query) < 1:
        return ok({"query": "", "suggestions": []}, 0)
    data = cached(f"suggest:{query.lower()}", SHORT, lambda: autocomplete(query, req_languages())) or {}
    flat, seen = [], set()
    for key in sorted(data, key=lambda k: data[k].get("position", 99)):
        for item in data[key]["items"][:5]:
            marker = (item.get("type"), item.get("id"))
            if marker in seen:
                continue
            seen.add(marker)
            flat.append({"text": item.get("title"), "type": item.get("type"), "id": item.get("id"),
                         "image": item.get("image") or item.get("artwork_url"), "subtitle": item.get("subtitle", item.get("artist", "")),
                         "token": item.get("token")})
    return ok({"query": query, "suggestions": flat, "grouped": data}, 600)


# ─── Songs, albums, playlists, artists ──────────────────────────────────────────
@app.route("/api/track/<track_id>")
@app.route("/api/song/<track_id>")
def api_track(track_id):
    track = song_details(track_id, request.args.get("quality", "320"))
    return ok(track, 3600) if track else not_found("Track not found")


@app.route("/api/play/<track_id>")
@app.route("/jiosaavn/stream")
def api_play(track_id=""):
    tid = track_id or request.args.get("id", "")
    if not tid:
        return jsonify({"error": "Missing track ID"}), 400
    url = resolve_stream(tid, request.args.get("quality", "320"))
    if not url:
        return not_found("Stream not found")
    resp = redirect(url, code=302)
    resp.headers["Cache-Control"] = "public, max-age=3600"
    return resp


@app.route("/api/lyrics/<track_id>")
def api_lyrics(track_id):
    data = cached(f"lyrics:{track_id}", 86400, lambda: lyrics(track_id))
    return ok(data, 86400) if data else not_found("Lyrics not available")


@app.route("/api/album", defaults={"album_id": None})
@app.route("/api/album/<album_id>")
def api_album(album_id):
    token = request.args.get("token")
    if not album_id and not token:
        return jsonify({"error": "Provide an album id or ?token="}), 400
    data = cached(f"album:{album_id or token}", HOURLY,
                  lambda: entity_details("album", album_id, token, languages=req_languages()))
    return ok(data, 3600) if data else not_found("Album not found")


@app.route("/api/playlist", defaults={"playlist_id": None})
@app.route("/api/playlist/<playlist_id>")
def api_playlist(playlist_id):
    token = request.args.get("token")
    if not playlist_id and not token:
        return jsonify({"error": "Provide a playlist id or ?token="}), 400
    limit = arg_int("limit", 50, 1, 100, "n")
    page = arg_int("page", 1, 1, 50, "p")
    data = cached(f"playlist:{playlist_id or token}:{page}:{limit}", HOURLY,
                  lambda: entity_details("playlist", playlist_id, token, limit, page, req_languages()))
    return ok(data, 1800) if data else not_found("Playlist not found")


@app.route("/api/artist", defaults={"artist_id": None})
@app.route("/api/artist/<artist_id>")
def api_artist(artist_id):
    token = request.args.get("token")
    if not artist_id and not token:
        return jsonify({"error": "Provide an artist id or ?token="}), 400
    n_song = arg_int("songs", 30, 1, 50)
    n_album = arg_int("albums", 20, 0, 50)
    data = cached(f"artist:{artist_id or token}:{n_song}:{n_album}", HOURLY,
                  lambda: artist_details(artist_id, token, n_song, n_album, req_languages()))
    return ok(data, 3600) if data else not_found("Artist not found")


@app.route("/api/artist/<artist_id>/songs")
def api_artist_songs(artist_id):
    page = arg_int("page", 1, 1, 200, "p")
    sort = request.args.get("sort", "latest")
    if sort not in ("latest", "alphabetical", "popularity"):
        sort = "latest"
    data = cached(f"artistsongs:{artist_id}:{page}:{sort}", HOURLY,
                  lambda: artist_songs(artist_id, page, sort, req_languages()))
    return ok({**(data or {"tracks": [], "total": 0}), "page": page, "sort": sort}, 3600)


@app.route("/api/related")
@app.route("/api/recommendations")
@app.route("/api/up-next")
def api_related():
    song_id = (request.args.get("id") or request.args.get("track_id") or "").strip()
    title = (request.args.get("title") or "").strip()
    artist = (request.args.get("artist") or "").strip()
    limit = arg_int("limit", 15, 1, 50)
    exclude = [x.strip() for x in (request.args.get("exclude") or "").split(",") if x.strip()][:200]
    if not song_id and not title and not artist:
        return jsonify({"error": "Provide ?id= or ?title=&artist="}), 400
    seed, tracks = related_tracks(song_id, title, artist, limit, exclude, req_languages())
    return ok({"seed": {k: seed.get(k) for k in ("id", "title", "artist", "language")} if seed else None,
               "tracks": tracks, "total": len(tracks), "source": "jiosaavn_reco"}, 0 if exclude else 900)


# ─── Radio ──────────────────────────────────────────────────────────────────────
@app.route("/api/radio/stations")
def api_radio_stations():
    languages = req_languages()
    home_data = live_home(languages)
    jio_radio = next((s["items"] for s in home_data.get("sections", []) if s["key"] == "radio"), [])
    return ok({"stations": RADIO_STATIONS, "count": len(RADIO_STATIONS), "jiosaavn_stations": jio_radio}, 3600)


@app.route("/api/radio/stream/<station_id>")
def api_radio_stream(station_id):
    station = next((s for s in RADIO_STATIONS if s["id"] == station_id), None)
    return redirect(station["stream_url"], code=302) if station else not_found("Station not found")


# ─── YouTube (yt-dlp) ───────────────────────────────────────────────────────────
def _ydl_opts(**extra):
    opts = {"quiet": True, "no_warnings": True, "noplaylist": True, **extra}
    if os.path.exists(COOKIES_FILE):
        opts["cookiefile"] = COOKIES_FILE
    return opts


def _youtube_unavailable():
    return jsonify({"error": "yt-dlp is not installed on this server"}), 503


@app.route("/stream")
def youtube_stream():
    if not YTDLP_AVAILABLE:
        return _youtube_unavailable()
    video_url = request.args.get("url") or request.args.get("video_url")
    if not video_url:
        return jsonify({"error": "No URL provided"}), 400
    try:
        with yt_dlp.YoutubeDL(_ydl_opts(format="bestaudio[ext=m4a]/bestaudio/best")) as ydl:
            info = ydl.extract_info(video_url, download=False)
        stream_url = info.get("url")
        if not stream_url and info.get("formats"):
            audio = [f for f in info["formats"] if f.get("vcodec") == "none" and f.get("acodec") != "none"]
            audio.sort(key=lambda f: f.get("abr") or 0, reverse=True)
            stream_url = (audio or info["formats"])[0 if audio else -1]["url"]
        if not stream_url:
            return jsonify({"error": "Could not extract stream URL"}), 500
        return jsonify({"stream_url": stream_url, "title": info.get("title", ""),
                        "thumbnail": info.get("thumbnail", ""), "duration": info.get("duration", 0),
                        "uploader": info.get("uploader", "")})
    except Exception as exc:
        return jsonify({"error": f"yt-dlp error: {exc}"}), 500


@app.route("/search")
def youtube_search():
    if not YTDLP_AVAILABLE:
        return _youtube_unavailable()
    query = request.args.get("q") or request.args.get("query", "")
    limit = arg_int("limit", 10, 1, 30)
    if not query:
        return jsonify({"error": "No query provided"}), 400
    try:
        with yt_dlp.YoutubeDL(_ydl_opts(extract_flat=True)) as ydl:
            result = ydl.extract_info(f"ytsearch{limit}:{query}", download=False)
        tracks = []
        for entry in result.get("entries") or []:
            if not entry:
                continue
            vid = entry.get("id", "")
            tracks.append({"id": vid, "title": entry.get("title", ""),
                           "url": f"https://www.youtube.com/watch?v={vid}",
                           "thumbnail": entry.get("thumbnail") or f"https://i.ytimg.com/vi/{vid}/hqdefault.jpg",
                           "duration": entry.get("duration", 0),
                           "uploader": entry.get("uploader") or entry.get("channel", "")})
        return jsonify({"tracks": tracks})
    except Exception as exc:
        return jsonify({"error": str(exc)}), 500


def _delete_old_files():
    for name in os.listdir(DOWNLOAD_FOLDER):
        path = os.path.join(DOWNLOAD_FOLDER, name)
        if os.path.isfile(path) and time.time() - os.path.getctime(path) > 1800:
            try:
                os.remove(path)
            except OSError:
                pass


@app.route("/download")
def youtube_download():
    if not YTDLP_AVAILABLE:
        return _youtube_unavailable()
    _delete_old_files()
    video_url = request.args.get("url")
    media_type = request.args.get("type", "audio")
    if not video_url:
        return jsonify({"error": "No URL provided"}), 400
    file_id = str(uuid.uuid4())
    template = os.path.join(DOWNLOAD_FOLDER, f"{file_id}.%(ext)s")
    if media_type == "audio":
        filename = f"{file_id}.mp3"
        command = [sys.executable, "-m", "yt_dlp", "-x", "--audio-format", "mp3", "--audio-quality", "0", "-o", template]
    elif media_type == "video":
        filename = f"{file_id}.mp4"
        command = [sys.executable, "-m", "yt_dlp", "-f", "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best",
                   "-o", template]
    else:
        return jsonify({"error": "Invalid type. Must be 'audio' or 'video'"}), 400
    if os.path.exists(COOKIES_FILE):
        command.extend(["--cookies", COOKIES_FILE])
    command.extend(["--", video_url])
    try:
        subprocess.run(command, check=True, timeout=240)
        return jsonify({"file_url": f"{request.host_url}static/{filename}", "message": "Download successful"})
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as exc:
        return jsonify({"error": str(exc)}), 500


@app.route("/static/<path:filename>")
def serve_static(filename):
    return send_from_directory(DOWNLOAD_FOLDER, filename)


@app.route("/channel")
def get_channel():
    return jsonify({"channel_link": "https://m.youtube.com/mirrykal"})


# ─── Background workers (not on Vercel serverless) ──────────────────────────────
_WORKERS_STARTED = False


def start_background_workers():
    global _WORKERS_STARTED
    if _WORKERS_STARTED or IS_VERCEL or os.environ.get("DISABLE_BACKGROUND_REFRESH"):
        return
    _WORKERS_STARTED = True
    threading.Thread(target=_hourly_refresher, daemon=True).start()
    threading.Thread(target=_keep_alive, daemon=True).start()


start_background_workers()


# Ensure ASGI compatibility if loaded by an ASGI runner (e.g. uvicorn, hypercorn)
try:
    from a2wsgi import WSGIMiddleware
    asgi_app = WSGIMiddleware(app)
except Exception:
    asgi_app = app


def uvicorn_entry():
    """CLI runner invoked if the host start command is 'uvicorn server.py'."""
    import sys
    # Normalize command line args if 'server.py' was passed without '<module>:<attr>' format
    args = list(sys.argv[1:])
    for i, a in enumerate(args):
        if a == "server.py" or (a.endswith(".py") and ":" not in a):
            args[i] = "server:app"
    if not any(":" in a for a in args):
        args.insert(0, "server:app")
    
    port = os.environ.get("PORT", "5000")
    if "--port" not in args:
        args.extend(["--port", str(port)])
    if "--host" not in args:
        args.extend(["--host", "0.0.0.0"])

    try:
        import uvicorn
        uvicorn.main.main(args=args)
    except Exception:
        # Fallback directly to gunicorn if uvicorn invocation fails
        uvicorn_fallback()


def uvicorn_fallback():
    """Fallback runner if the host start command is 'uvicorn ...' (see setup.py entry point)."""
    port = os.environ.get("PORT", "5000")
    try:
        os.execvp("gunicorn", ["gunicorn", "-b", f"0.0.0.0:{port}", "--threads", "8", "--timeout", "60", "server:app"])
    except Exception:
        app.run(host="0.0.0.0", port=int(port))


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    print(f"Starting {SERVICE_NAME} v{VERSION} on port {port}...")
    app.run(host="0.0.0.0", port=port, debug=False, threaded=True)
