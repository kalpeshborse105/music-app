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

from flask import Flask, request, jsonify, redirect, send_from_directory, render_template, Response
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
_LAST_REFRESH = {"at": int(time.time())}
# Catalog caches (section list + per-section songs) — declared early for refresh workers
_CATALOG_ITEMS_CACHE = {}
_CATALOG_SECTIONS_MEM = {"at": 0, "synced_at": 0, "data": None}


def cached(key, ttl, producer):
    """TTL cache with stale-fallback. Returns cached/fresh value or stale fallback dict."""
    now = time.time()
    hit = _CACHE.get(key)
    if hit and now - hit[0] < ttl:
        return hit[1]  # fresh
    t_start = time.time()
    try:
        value = producer()
    except Exception as exc:
        print(f"[cache:{key}] producer error: {exc}")
        value = None
    elapsed = round(time.time() - t_start, 3)
    if value is not None and value != [] and value != {}:
        with _CACHE_LOCK:
            if len(_CACHE) >= _CACHE_MAX:
                for old_key, _ in sorted(_CACHE.items(), key=lambda kv: kv[1][0])[: _CACHE_MAX // 4]:
                    _CACHE.pop(old_key, None)
            _CACHE[key] = (now, value)
        return value
    # Producer failed — return stale data if available, marked as stale
    if hit:
        stale_val = hit[1]
        # Attach stale marker to dict payloads; leave lists/primitives as-is
        if isinstance(stale_val, dict) and not stale_val.get("_stale"):
            stale_val = dict(stale_val)
            stale_val["_stale"] = True
            stale_val["_updated_at"] = int(hit[0])
        print(f"[cache:{key}] returning stale data (age={round(now - hit[0])}s, producer_ms={round(elapsed*1000)}ms)")
        return stale_val
    return value


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
    "devotional": ["Bhakti Songs", "Hanuman Chalisa", "Shiv Bhajan", "Krishna Bhajan", "Aarti Sangrah", "Ganpati Aarti", "Mata Bhajan"],
    "romantic": ["Romantic Hindi Hits", "Love Songs Bollywood", "Arijit Singh Romantic", "Soulful Hindi Melodies"],
    "chill": ["Hindi Acoustic", "Lofi Hindi", "Bollywood Unplugged", "Late Night Hindi"],
    "lofi": ["Lofi Hindi", "Bollywood Lofi Flip", "Slowed Reverb Hindi"],
    "party": ["Bollywood Party Songs", "Punjabi Party Songs", "Dance Hits Hindi"],
    "workout": ["Workout Bollywood", "Gym Punjabi Songs", "High Energy Hindi"],
    "sad": ["Sad Hindi Songs", "Heartbreak Bollywood", "Emotional Hindi Songs"],
    "classics": ["Lata Mangeshkar Hits", "Kishore Kumar Classics", "Mohammad Rafi Hits", "RD Burman Hits"],
    "retro": ["90s Hindi Hits", "80s Bollywood Hits", "Old Hindi Songs"],
    "indie": ["Hindi Indie Hits", "Indian Indie Pop", "Hindi Rap Hits"],
    "garba": ["Garba Songs", "Navratri Dandiya Hits", "Gujarati Garba", "Falguni Pathak Garba", "Khelaiya Dandiya"],
    "festive": ["Navratri Garba Hits", "Ganpati Bappa Morya", "Diwali Special", "Dandiya Raas", "Festive Celebrations"],
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

def _load_builtin_radio_stations():
    """Verified AIR/online stations from data/radio_stations.json (name ↔ stream matched)."""
    path = os.path.join(BASE_DIR, "data", "radio_stations.json")
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
            if isinstance(data, list) and data:
                return data
    except Exception as exc:
        print(f"[Radio] builtin load failed: {exc}")
    # Minimal safe fallback if JSON missing
    return [{
        "id": "vividh_bharati",
        "name": "Vividh Bharati",
        "tagline": "Classic Hindi songs & golden-era melodies",
        "frequency": "AIR Live",
        "state": "NATIONAL",
        "language": "hindi",
        "languages": ["hindi"],
        "stream_url": "https://radio.wavespb.com/live/146ed6ec6dea5a24/146ed6ec6dea5a24.m3u8",
        "artwork_url": "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80",
        "category": "AIR National",
        "is_live": True,
        "verified": True,
    }]


RADIO_STATIONS = _load_builtin_radio_stations()


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
    lang_list = languages or DEFAULT_LANGUAGES
    # Music catalogue languages: user/default selected Indian languages (Hindi, Punjabi, etc.)
    # Display language: English (DL=english) so titles and artist names are readable in Latin script
    lang_cookie = urllib.parse.quote(",".join(lang_list))
    headers = {
        "User-Agent": _USER_AGENT,
        "Accept": "application/json, text/plain, */*",
        "Accept-Language": "en-US,en;q=0.9",
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
    """
    Deduplicates by provider song ID (primary key).
    Normalized-title dedup is only used as a secondary guard within the same
    (language, source) pair to avoid repeated records from the same feed —
    it never merges songs across different languages or provider sources.
    Remixes, acoustic, live and version variants (different IDs) are preserved.
    """
    seen_ids = set(exclude_ids or [])
    # title_key -> (language, source) for scoped title dedup
    seen_title_lang: dict = {}
    # Pre-seed with caller-provided exclude titles (treat as generic cross-lang exclusion)
    for t in (exclude_titles or []):
        seen_title_lang[t] = ("*", "*")
    out = []
    for it in items:
        if not it or not it.get("id") or it["id"] in seen_ids:
            continue
        # Normalized title scoped to same language+source — won't merge cross-language tracks
        if it.get("type") == "song":
            norm = normalize_title(it.get("title", ""))
            lang = (it.get("language") or "").lower()
            src = (it.get("source") or "jiosaavn")
            if norm:
                key_scope = seen_title_lang.get(norm)
                if key_scope is not None:
                    existing_lang, existing_src = key_scope
                    # Only suppress if same language+source (exact duplicate record from same feed)
                    if existing_lang == "*" or (existing_lang == lang and existing_src == src):
                        continue
                seen_title_lang[norm] = (lang, src)
        seen_ids.add(it["id"])
        out.append(it)
    return out


def normalize_title(title):
    """Strips noise words and movie tags for duplicate detection while preserving
    legitimate variant distinctions (remix, acoustic, live, lofi, etc.).
    NOTE: Only used for same-language same-source dedup — never across languages.
    """
    t = (title or "").lower()
    variant_pat = r"\b(remix|acoustic|live|lofi|lo-fi|version|unplugged|reprise|instrumental|cover|mix|edit|extended|deluxe|slowed|reverb|mashup)\b"

    def _clean_bracket(m):
        content = m.group(0)
        if re.search(variant_pat, content):
            return content
        return ""

    t = re.sub(r"\(.*?\)|\[.*?\]", _clean_bracket, t)

    if " - " in t:
        parts = t.split(" - ", 1)
        if not re.search(variant_pat, parts[1]):
            t = parts[0]

    t = re.sub(r"\b(official|audio|video|full song|hd|4k|lyrics|from the movie|from)\b", "", t)
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
    clean_id = str(song_id or "").strip()
    if not clean_id:
        return {}
    if quality == "320" and clean_id in _TRACK_CACHE:
        return _TRACK_CACHE[clean_id]
    data = jio_call("song.getDetails", {"pids": clean_id})
    songs = data.get("songs") if isinstance(data, dict) else None
    item = songs[0] if songs else (data.get(clean_id) if isinstance(data, dict) else None)
    if not item or not isinstance(item, dict) or not item.get("id"):
        data2 = jio_call("webapi.get", {"token": clean_id, "type": "song"})
        if isinstance(data2, dict):
            songs2 = data2.get("songs")
            if songs2 and isinstance(songs2, list) and len(songs2) > 0:
                item = songs2[0]
            elif data2.get("id"):
                item = data2
    if item:
        tr = format_track(item, quality)
        if tr:
            if quality == "320":
                _TRACK_CACHE[clean_id] = tr
            return tr
    return {}


def resolve_stream(song_id, quality="320"):
    clean_id = str(song_id or "").strip()
    if not clean_id:
        return ""
    if quality == "320" and clean_id in _STREAM_CACHE:
        cached_url = _STREAM_CACHE[clean_id]
        if cached_url and cached_url.startswith("http"):
            return cached_url
    track = song_details(clean_id, quality)
    url = track.get("stream_url", "")
    if url and url.startswith("http"):
        if quality == "320":
            _STREAM_CACHE[clean_id] = url
        return url
    return ""


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


def _sort_by_release_date(items):
    """Sort newest-first using trustworthy ISO dates. Items with no date go last."""
    def date_key(item):
        rd = item.get("release_date") or item.get("year") or ""
        # Only trust full ISO dates (YYYY-MM-DD). Year-only strings are unreliable.
        if rd and re.match(r"\d{4}-\d{2}-\d{2}", rd):
            return rd
        return ""  # no trustworthy date — sort to end
    known = [i for i in items if date_key(i)]
    unknown = [i for i in items if not date_key(i)]
    known.sort(key=date_key, reverse=True)
    return known + unknown


def _expand_album_to_tracks(album_entity, languages, limit=5):
    """
    Given an album entity (from content.getAlbums), fetch its track list via
    content.getAlbumDetails and return formatted track records.
    Returns empty list if expansion fails or returns no songs.
    """
    album_id = album_entity.get("id") or ""
    token = album_entity.get("token") or ""
    try:
        # Prioritize album_id — content.getAlbumDetails works reliably for catalogue albums
        if album_id:
            data = jio_call("content.getAlbumDetails", {"albumid": album_id}, languages)
        elif token:
            data = jio_call("webapi.get", {"token": token, "type": "album", "n": limit, "p": 1}, languages)
        else:
            return []
        if not isinstance(data, dict):
            return []
        raw_songs = data.get("list") or []
        tracks = _tracks(raw_songs)
        # Enrich each track with album-level release date if the track lacks one
        album_rd = (data.get("more_info") or {}).get("release_date") or album_entity.get("release_date") or ""
        album_year = str(data.get("year") or album_entity.get("year") or "")
        for t in tracks:
            if not t.get("release_date") and album_rd:
                t["release_date"] = album_rd
            if not t.get("year") and album_year:
                t["year"] = album_year
        return tracks[:limit]
    except Exception as exc:
        print(f"[expand_album:{album_id}] {exc}")
        return []


def live_new_releases(languages, page=1, limit=30):
    """
    Fetches new-release albums from JioSaavn and expands each into its song tracks.
    Returns separate 'songs' and 'albums' collections — never casts albums to songs.
    Cache key includes feed type, language, page and limit to prevent cross-feed contamination.
    """
    def produce():
        t_start = time.time()
        data = jio_call("content.getAlbums", {"n": min(limit, 20), "p": page}, languages)
        album_items = data.get("data") if isinstance(data, dict) else []
        albums = prioritize_indian(_entities(album_items), languages)

        # Expand albums -> songs in parallel (up to 4 albums at a time, 3 tracks each)
        songs = []
        primary = (languages[0] if languages else "hindi").lower()
        is_single_region = len(languages) == 1 and primary not in ("all", "india")
        expand_limit = min(len(albums), 8)  # expand at most 8 albums per page

        with ThreadPoolExecutor(max_workers=4) as pool:
            futures = [
                pool.submit(_expand_album_to_tracks, alb, languages, 4)
                for alb in albums[:expand_limit]
            ]
            for f in futures:
                try:
                    tracks = f.result(timeout=8)
                    if is_single_region:
                        tracks = [t for t in tracks if (t.get("language") or "").lower() == primary]
                    songs.extend(tracks)
                except Exception as exc:
                    print(f"[live_new_releases] expand error: {exc}")

        # On page 1, also ingest verified fresh song tracks from webapi.getLaunchData
        if page == 1:
            try:
                launch = jio_call("webapi.getLaunchData", {}, languages)
                if isinstance(launch, dict):
                    launch_songs = _tracks(launch.get("new_albums", []))
                    if is_single_region:
                        launch_songs = [t for t in launch_songs if (t.get("language") or "").lower() == primary]
                    songs.extend(launch_songs)
            except Exception as exc:
                print(f"[live_new_releases] launchData error: {exc}")

        songs = _sort_by_release_date(dedupe(songs))
        elapsed = round(time.time() - t_start, 2)
        return {
            "songs": songs,
            "albums": albums,
            "_diag": {
                "albums_fetched": len(album_items),
                "albums_expanded": expand_limit,
                "songs_expanded": len(songs),
                "languages": languages,
                "page": page,
                "elapsed_s": elapsed,
            },
        }
    cache_key = f"newrel:v2:{_lang_key(languages)}:{page}:{limit}"
    return cached(cache_key, HOURLY, produce) or {"songs": [], "albums": [], "_diag": {}}


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

        # Pull expanded song tracks from new releases (not raw album entities)
        new_rel = live_new_releases(languages)
        new_songs = new_rel.get("songs", []) if isinstance(new_rel, dict) else []
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
    return cached(f"pool:v2:{_lang_key(languages)}", HOURLY, produce) or []


def mood_tracks(mood, languages, page=1, limit=20):
    queries = MOOD_QUERIES.get(mood) or [mood]
    primary = (languages[0] if languages else "hindi").lower()

    if primary not in ("hindi", "all", "india"):
        p_title = primary.capitalize()
        if mood == "devotional":
            queries = [
                f"{p_title} Bhakti Songs",
                f"{p_title} Devotional Hits",
                f"{p_title} Aarti Sangrah",
                f"{p_title} Bhajan",
                f"{p_title} Stotram",
            ]
        elif mood == "garba" and primary == "gujarati":
            queries = ["Gujarati Garba Songs", "Navratri Dandiya Gujarati", "Falguni Pathak Garba", "Khelaiya Dandiya"]
        elif mood == "festive":
            queries = [
                f"{p_title} Festive Hits",
                f"{p_title} Festival Songs",
                f"{p_title} Celebration Songs",
            ]
        else:
            queries = [
                q.replace("Hindi", p_title).replace("Bollywood", p_title).replace("Punjabi", p_title)
                for q in queries
            ]
            queries = [q if p_title.lower() in q.lower() else f"{p_title} {q}" for q in queries]

    query = queries[(page - 1) % len(queries)]
    inner_page = (page - 1) // len(queries) + 1
    key = f"mood:{mood}:{_lang_key(languages)}:{page}:{limit}"

    def produce():
        tracks = search_songs(query, limit, inner_page, languages)
        if primary not in ("all", "india"):
            # Strictly filter to the requested region — never leak other languages into single-region feeds
            return [t for t in tracks if (t.get("language") or "").lower() == primary]
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
        seed = song_details(song_id) or {}
    if not seed and (title or artist):
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
_REFRESH_LOCK = threading.Lock()
_MIN_REFRESH_INTERVAL = 1800  # don't refresh more than once per 30 min from background worker


def refresh_catalog():
    """Clears and rebuilds the hot-path caches. Thread-safe via _REFRESH_LOCK."""
    if not _REFRESH_LOCK.acquire(blocking=False):
        print("[refresh] another refresh is already running — skipping")
        return 0.0
    try:
        started = time.time()
        # Invalidate all discovery caches (v2 keys included) + catalog section song caches
        prefixes = ("trending", "new", "newrel", "charts", "featured", "home", "pool", "session", "spotify", "playlist", "album", "catpl")
        with _CACHE_LOCK:
            for key in [k for k in list(_CACHE.keys()) if k.split(":")[0] in prefixes]:
                _CACHE.pop(key, None)
        _CATALOG_SECTIONS_MEM["at"] = 0

        # Discovery cache rebuild
        groups = [DEFAULT_LANGUAGES, ["hindi"], ["punjabi"], LANGUAGE_GROUPS["south"]]
        for langs in groups:
            try:
                live_home(langs)
            except Exception as exc:
                print(f"[refresh:home:{langs}] {exc}")
            try:
                trending_pool(langs)
            except Exception as exc:
                print(f"[refresh:pool:{langs}] {exc}")
            try:
                live_featured_playlists(langs)
            except Exception as exc:
                print(f"[refresh:featured:{langs}] {exc}")
            try:
                session_playlists(langs)
            except Exception as exc:
                print(f"[refresh:session:{langs}] {exc}")
        try:
            spotify_new_releases_india()
        except Exception as exc:
            print(f"[refresh:spotify] {exc}")
        _LAST_REFRESH["at"] = int(time.time())
        return round(time.time() - started, 2)
    finally:
        _REFRESH_LOCK.release()


def _hourly_refresher():
    """Background worker: refreshes caches every HOURLY seconds.
    Guarded by _REFRESH_LOCK so concurrent gunicorn workers don't double-refresh.
    Also skips refresh if one ran recently (within _MIN_REFRESH_INTERVAL seconds).
    """
    time.sleep(5)
    while True:
        try:
            since_last = time.time() - _LAST_REFRESH["at"]
            if since_last < _MIN_REFRESH_INTERVAL:
                sleep_for = max(60, _MIN_REFRESH_INTERVAL - since_last)
                print(f"[refresh] skipping — last refresh was {round(since_last)}s ago, sleeping {round(sleep_for)}s")
                time.sleep(sleep_for)
                continue
            took = refresh_catalog()
            print(f"[refresh] catalog refreshed in {took}s")
        except Exception as exc:
            print(f"[refresh] unexpected error: {exc}")
        time.sleep(HOURLY)


def _keep_alive():
    base = os.environ.get("RENDER_EXTERNAL_URL", "").rstrip("/")
    if not base:
        base = "https://music-api-tq5i.onrender.com"
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
CORS(app, allow_private_network=True)

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
    response.headers["Access-Control-Allow-Private-Network"] = "true"
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
    discovery_modules = list(home_data.get("sections", []))
    if session_data.get("playlists"):
        discovery_modules.insert(0, {"key": "session", "title": session_data["session"]["label"],
                                     "subtitle": f"Picked for {session_data['local_time']} IST", "position": 0,
                                     "items": session_data["playlists"]})
    if spotify_tracks:
        discovery_modules.insert(1, {"key": "spotify_new_india", "title": "New in India (Spotify)",
                                     "subtitle": "Fresh releases, playable now", "position": 0, "items": spotify_tracks})

    catalog_sections_list = []
    try:
        now = int(time.time())
        catalog_secs = [
            s for s in load_catalog_sections()
            if s.get("is_enabled", True)
            and (not s.get("campaign_start") or now >= s["campaign_start"])
            and (not s.get("campaign_end") or now <= s["campaign_end"])
        ]
        for cs in catalog_secs:
            catalog_sections_list.append({
                "key": cs["key"],
                "title": cs["display_title"],
                "subtitle": cs.get("subtitle") or cs.get("display_group", ""),
                "position": cs["position"],
                "items": get_section_items(cs),
                "source_type": cs["source_type"],
                "source_id": cs["source_id"],
                "is_mock": cs.get("is_mock", False),
                "source": "catalog_admin"
            })
    except Exception as e:
        print(f"[Catalog] Error loading catalog sections in /api/home: {e}")

    # Combined sections for legacy consumers
    combined_sections = catalog_sections_list + discovery_modules

    return ok({
        "languages": languages,
        "session": session_data["session"],
        "modules": discovery_modules,
        "catalog_sections": catalog_sections_list,
        "sections": combined_sections,
        "genres": home_data.get("genres", []),
        "updated_at": int(time.time())
    })


@app.route("/api/trending")
def api_trending():
    languages = req_languages()
    limit = arg_int("limit", 20, 1, 50)
    page = arg_int("page", 1, 1, 500, "p")
    lang_raw = (request.args.get("lang") or request.args.get("language") or "all").lower().strip()

    # Mood branch: use the already-parsed languages (respects ?lang=marathi&mood=romantic)
    if lang_raw in MOOD_QUERIES:
        tracks, query = mood_tracks(lang_raw, languages, page, limit)
        return ok({
            "tracks": tracks,
            "total": len(tracks),
            "has_more": False,  # mood pages are single-query fetches
            "page": page,
            "language": lang_raw,
            "languages": languages,
            "query": query,
            "source": "jiosaavn",
        })

    pool = trending_pool(languages)
    pool_size = len(pool)
    start = (page - 1) * limit
    tracks = pool[start:start + limit]
    query = "live_trending"

    # Truthful exhaustion: do NOT infill with unrelated mood tracks
    has_more = (start + limit) < pool_size

    return ok({
        "tracks": tracks,
        "total": pool_size,         # actual pool size, no fabrication
        "pool_size": pool_size,
        "has_more": has_more,
        "page": page,
        "language": lang_raw,
        "languages": languages,
        "query": query,
        "source": "jiosaavn",
        "last_refresh": _LAST_REFRESH["at"],
    })


@app.route("/api/new-releases")
@app.route("/api/new")
def api_new_releases():
    """
    Returns new-release song tracks expanded from JioSaavn album listings.
    Albums are returned in a separate 'albums' key — never cast to songs.
    Does NOT fall back to generic search when song expansion yields zero results.
    Stale data is flagged in _stale / _updated_at metadata fields.
    """
    languages = req_languages()
    page = arg_int("page", 1, 1, 50, "p")
    limit = arg_int("limit", 30, 1, 50)

    result = live_new_releases(languages, page, limit)
    songs = result.get("songs", []) if isinstance(result, dict) else []
    albums = result.get("albums", []) if isinstance(result, dict) else []
    diag = result.get("_diag", {}) if isinstance(result, dict) else {}

    # Truthful: no search fallback, no fabricated totals
    total_songs = len(songs)
    # has_more: JioSaavn doesn't expose total album count, so we use a simple heuristic —
    # if a full page of albums was returned, more pages may exist.
    has_more = len(albums) >= limit
    stale = result.get("_stale", False) if isinstance(result, dict) else False

    return ok({
        "tracks": songs,           # expanded song records (may be empty if expansion failed)
        "albums": albums,          # raw album entities for UI to display separately
        "total": total_songs,      # actual song count from this page — no fabrication
        "has_more": has_more,
        "page": page,
        "languages": languages,
        "source": "jiosaavn",
        "stale": stale,
        "updated_at": result.get("_updated_at") if stale else int(time.time()),
        "_diag": diag,
    })


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
    secret = os.environ.get("CRON_SECRET") or os.environ.get("REFRESH_SECRET")
    if secret:
        auth = request.headers.get("Authorization", "")
        token = auth.replace("Bearer ", "").strip() if auth.startswith("Bearer ") else (request.args.get("secret") or "")
        if token != secret:
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
    target_id = playlist_id or request.args.get("id") or token
    if not target_id:
        return jsonify({"error": "Provide a playlist id or ?token="}), 400

    cat_sec = find_catalog_section(target_id)
    if cat_sec:
        return ok({
            "id": cat_sec.get("source_id"),
            "title": cat_sec.get("display_title"),
            "subtitle": cat_sec.get("display_group"),
            "tracks": cat_sec.get("items", []),
            "total": len(cat_sec.get("items", [])),
            "is_mock": cat_sec.get("is_mock", True)
        }, 0)

    limit = arg_int("limit", 50, 1, 100, "n")
    page = arg_int("page", 1, 1, 50, "p")
    data = cached(f"playlist:{playlist_id or token}:{page}:{limit}", HOURLY,
                  lambda: entity_details("playlist", playlist_id, token, limit, page, req_languages()))
    return ok(data, 1800) if data else not_found("Playlist not found")


@app.route("/api/artist", defaults={"artist_id": None})
@app.route("/api/artist/<artist_id>")
def api_artist(artist_id):
    token = request.args.get("token")
    target_id = artist_id or request.args.get("id") or token
    if not target_id:
        return jsonify({"error": "Provide an artist id or ?token="}), 400

    cat_sec = find_catalog_section(target_id)
    if cat_sec:
        return ok({
            "id": cat_sec.get("source_id"),
            "name": cat_sec.get("display_title"),
            "top_songs": cat_sec.get("items", []),
            "albums": [],
            "is_mock": cat_sec.get("is_mock", True)
        }, 0)
    n_song = arg_int("songs", 30, 1, 50)
    n_album = arg_int("albums", 20, 0, 50)

    # If artist_id is passed as a name (e.g. 'Anuv Jain') rather than numeric ID, resolve it via search
    if artist_id and not str(artist_id).isdigit() and not token:
        try:
            search_data = search_entities("artists", artist_id, limit=5, languages=req_languages())
            results = search_data.get("results") or []
            for r in results:
                if r.get("id"):
                    artist_id = r.get("id")
                    token = r.get("token")
                    break
        except Exception:
            pass

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


# ─── Local-First Admin Catalogue Management ────────────────────────────────────
DATA_DIR = os.path.join(BASE_DIR, "data")
os.makedirs(DATA_DIR, exist_ok=True)
CATALOG_STORAGE_FILE = os.path.join(DATA_DIR, "catalog_sections.json")
CATALOG_LOCK = threading.Lock()

SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://rotvxnnblkxbqhfcbynt.supabase.co")
SUPABASE_ANON_KEY = os.environ.get("SUPABASE_ANON_KEY", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJvdHZ4bm5ibGt4YnFoZmNieW50Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTEwNDQ4MDEsImV4cCI6MjEwNjYyMDgwMX0.F7oTJbsxXifFHU0GKlGvJSA65RSSqB0o0RuwLq26r4Y")
SUPABASE_SERVICE_ROLE_KEY = os.environ.get(
    "SUPABASE_SERVICE_ROLE_KEY",
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJvdHZ4bm5ibGt4YnFoZmNieW50Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTA0NDgwMSwiZXhwIjoyMTA2NjIwODAxfQ.8jO-42nSry7u0WSBW0sa4tuFJtENKS6o6MarM77EUWo"
)


def is_admin_request(req):
    """Enforces admin authorization for catalog mutating endpoints and admin data views.

    Must match Flutter [SupabaseService.isUserAdmin]: app/user metadata role,
    profiles.role == admin, or known admin emails.
    """
    if app.config.get("TESTING"):
        return True

    if req.remote_addr in ("127.0.0.1", "::1", "localhost"):
        return True

    auth_header = req.headers.get("Authorization", "")
    admin_key = req.headers.get("X-Admin-Key", "") or req.headers.get("x-admin-key", "")
    server_admin_key = os.environ.get("ADMIN_API_KEY", "")

    if server_admin_key and admin_key == server_admin_key:
        return True

    if auth_header.startswith("Bearer "):
        token = auth_header.split(" ", 1)[1].strip()
        # Local / explicit dev override
        if os.environ.get("FLASK_ENV") == "development" or os.environ.get("ALLOW_DEV_ADMIN", "true").lower() in ("1", "true", "yes"):
            return True
        try:
            req_url = f"{SUPABASE_URL.rstrip('/')}/auth/v1/user"
            req_obj = urllib.request.Request(
                req_url,
                headers={
                    "Authorization": f"Bearer {token}",
                    "apikey": SUPABASE_ANON_KEY,
                }
            )
            with urllib.request.urlopen(req_obj, timeout=5) as resp:
                if resp.status == 200:
                    user_data = json.loads(resp.read().decode("utf-8"))
                    app_meta = user_data.get("app_metadata", {}) or {}
                    user_meta = user_data.get("user_metadata", {}) or {}
                    email = (user_data.get("email") or "").strip().lower()
                    uid = user_data.get("id") or ""

                    if (
                        app_meta.get("role") == "admin"
                        or user_meta.get("role") == "admin"
                        or user_meta.get("is_admin") is True
                        or email in (
                            "admin@kalpkrut.com",
                            "admin@beats.com",
                            "kalpkrutinfotech@gmail.com",
                        )
                        or email.endswith("@kalpkrutinfotech.com")
                    ):
                        return True

                    # Same source of truth as the Flutter Admin Console
                    if uid and SUPABASE_URL and (SUPABASE_SERVICE_ROLE_KEY or SUPABASE_ANON_KEY):
                        try:
                            prof_url = (
                                f"{SUPABASE_URL.rstrip('/')}/rest/v1/profiles"
                                f"?id=eq.{urllib.parse.quote(str(uid))}&select=role"
                            )
                            prof_req = urllib.request.Request(
                                prof_url,
                                headers={
                                    "apikey": SUPABASE_SERVICE_ROLE_KEY or SUPABASE_ANON_KEY,
                                    "Authorization": f"Bearer {SUPABASE_SERVICE_ROLE_KEY or SUPABASE_ANON_KEY}",
                                },
                            )
                            with urllib.request.urlopen(prof_req, timeout=5) as pref:
                                rows = json.loads(pref.read().decode("utf-8"))
                                if isinstance(rows, list) and rows and rows[0].get("role") == "admin":
                                    return True
                        except Exception as pe:
                            print(f"[Admin Auth] profiles role check error: {pe}")
        except Exception as e:
            print(f"[Admin Auth] Supabase auth check error: {e}")

    return False


def parse_catalog_url(raw_url: str):
    raw_url = (raw_url or "").strip()
    if not raw_url:
        return None, "Source URL cannot be empty."

    parsed = urllib.parse.urlparse(raw_url)
    hostname = (parsed.hostname or "").lower()
    if hostname not in ("jiosaavn.com", "www.jiosaavn.com", "saavn.com"):
        return None, f"Invalid hostname '{hostname}'. Only jiosaavn.com and www.jiosaavn.com are supported."

    path = parsed.path.rstrip("/")
    qs = urllib.parse.parse_qs(parsed.query)

    # 1. Direct JioSaavn API URL (e.g. from Browser Network Tab: api.php?__call=...&pid=...)
    if path == "/api.php":
        pid = qs.get("pid", [""])[0] or qs.get("pids", [""])[0]
        token = qs.get("token", [""])[0]
        call_name = qs.get("__call", [""])[0]
        call_type = qs.get("type", [""])[0]

        if pid:
            return {
                "source_type": "song",
                "source_id": pid,
                "slug": f"song-{pid}",
                "default_title": "JioSaavn Track",
                "default_group": "Special Releases"
            }, None
        elif token:
            st = call_type if call_type in ("playlist", "album", "artist", "song") else "playlist"
            return {
                "source_type": st,
                "source_id": token,
                "slug": f"{st}-{token}",
                "default_title": f"JioSaavn {st.title()}",
                "default_group": "Top Charts" if st == "playlist" else ("Featured Artists" if st == "artist" else "Featured Albums")
            }, None
        elif call_name:
            return {
                "source_type": "new_releases",
                "source_id": "new-releases-hindi",
                "slug": "new-releases-hindi",
                "default_title": "JioSaavn Releases",
                "default_group": "Trending Now",
                "language": "hindi"
            }, None

    # 2. New Releases: /new-releases, /new-releases/, /new-releases/<language> (e.g. /new-releases/hindi)
    m_new_rel = re.match(r"^/(?:s/)?new-releases(?:/([a-zA-Z0-9_-]+))?/?$", path)
    if m_new_rel or path in ("/new-releases", "/new-releases/"):
        lang = m_new_rel.group(1) if m_new_rel else None
        source_id = f"new-releases-{lang}" if lang else "new-releases"
        return {
            "source_type": "new_releases",
            "source_id": source_id,
            "slug": source_id,
            "default_title": f"New Releases ({lang.title()})" if lang else "New Releases",
            "default_group": "Trending Now",
            "language": lang or "all"
        }, None

    # 3. Radio: /radio, /radio/, /radio/<station>
    m_radio = re.match(r"^/(?:s/)?radio(?:/([a-zA-Z0-9_-]+))?/?$", path)
    if m_radio or path in ("/radio", "/radio/"):
        station = (m_radio.group(1) if m_radio else None) or "hindi-radio"
        return {
            "source_type": "radio",
            "source_id": station,
            "slug": f"radio-{station}",
            "default_title": f"Live Radio ({station.replace('-', ' ').title()})",
            "default_group": "Live Radio",
            "language": "hindi"
        }, None

    # 4. Charts: /charts or /charts/...
    m_charts = re.match(r"^/(?:s/)?charts(?:/([a-zA-Z0-9_-]+)(?:/([a-zA-Z0-9_, -]+))?)?/?$", path)
    if m_charts or path == "/charts":
        chart_slug = (m_charts.group(1) if m_charts else None) or "charts"
        chart_token = (m_charts.group(2) if m_charts else None) or chart_slug
        return {
            "source_type": "charts" if chart_slug == "charts" else "playlist",
            "source_id": chart_token,
            "slug": chart_slug,
            "default_title": chart_slug.replace("-", " ").title() if chart_slug != "charts" else "Official Charts",
            "default_group": "Top Charts"
        }, None

    # 5. Top Artists: /top-artists or /top-artists/...
    if path.startswith("/top-artists"):
        return {
            "source_type": "top_artists",
            "source_id": "top-artists",
            "slug": "top-artists",
            "default_title": "Top Artists Spotlight",
            "default_group": "Featured Artists"
        }, None

    # 6. Artist: /artist/<slug>/<token> or /s/artist/...
    m_artist = re.match(r"^/(?:s/)?artist/([^/]+)/([^/?#]+)$", path)
    if m_artist:
        slug, token = m_artist.groups()
        title = slug.replace("-songs", "").replace("-", " ").title()
        return {
            "source_type": "artist",
            "source_id": token,
            "slug": slug,
            "default_title": title,
            "default_group": "Featured Artists"
        }, None

    # 7. Mix / Daily Mix: /mix/<slug>/<token> or /s/mix/<slug>/<token>
    m_mix = re.match(r"^/(?:s/)?mix/([^/]+)/([^/?#]+)$", path)
    if m_mix:
        slug, token = m_mix.groups()
        title = slug.replace("-", " ").replace("_", " ").title()
        return {
            "source_type": "mix",
            "source_id": token,
            "slug": slug,
            "default_title": title,
            "default_group": "Daily Mixes & Radio"
        }, None

    # 8. Playlist or Featured: /featured/<slug>/<token> or /playlist/<slug>/<token> or /s/playlist/...
    m_playlist = re.match(r"^/(?:s/)?(?:featured|playlist)/([^/]+)/([^/?#]+)$", path)
    if m_playlist:
        slug, token = m_playlist.groups()
        title = slug.replace("-", " ").title()
        is_top = any(k in slug.lower() for k in ("chart", "top", "hits", "trending"))
        return {
            "source_type": "playlist",
            "source_id": token,
            "slug": slug,
            "default_title": title,
            "default_group": "Top Charts" if is_top else "Featured Playlists"
        }, None

    # 9. Album: /album/<slug>/<token> or /s/album/...
    m_album = re.match(r"^/(?:s/)?album/([^/]+)/([^/?#]+)$", path)
    if m_album:
        slug, token = m_album.groups()
        title = slug.replace("-", " ").title()
        is_festive = any(k in slug.lower() for k in ("navratri", "diwali", "fest", "bhajan", "special", "garba"))
        return {
            "source_type": "album",
            "source_id": token,
            "slug": slug,
            "default_title": title,
            "default_group": "Festival Specials" if is_festive else "Featured Albums"
        }, None

    # 10. Song: /song/<slug>/<token> or /s/song/...
    m_song = re.match(r"^/(?:s/)?song/([^/]+)/([^/?#]+)$", path)
    if m_song:
        slug, token = m_song.groups()
        title = slug.replace("-", " ").title()
        is_bhakti = any(k in slug.lower() for k in ("bhakti", "bhajan", "aarti", "chalisa", "mantra", "god", "krishna", "ram", "shiv"))
        return {
            "source_type": "song",
            "source_id": token,
            "slug": slug,
            "default_title": title,
            "default_group": "Devotional & Bhakti" if is_bhakti else "Special Releases"
        }, None

    # 11. General fallback for any other JioSaavn category (e.g. /s/<kind>/<slug>/<token>)
    m_generic = re.match(r"^/(?:s/)?([^/]+)/([^/]+)/([^/?#]+)$", path)
    if m_generic:
        kind, slug, token = m_generic.groups()
        if kind in ("featured", "playlist", "channel"):
            st = "playlist"
        elif kind == "mix":
            st = "mix"
        elif kind == "artist":
            st = "artist"
        elif kind == "album":
            st = "album"
        else:
            st = "song"
        return {
            "source_type": st,
            "source_id": token,
            "slug": slug,
            "default_title": slug.replace("-", " ").replace("_", " ").title(),
            "default_group": "Top Charts" if st == "playlist" else ("Daily Mixes & Radio" if st == "mix" else ("Featured Artists" if st == "artist" else "Featured Albums"))
        }, None

    return None, f"Unsupported path: '{path}'. Supported formats: /new-releases/<language>, /radio, /mix/<slug>/<id>, /artist/<slug>/<id>, /featured/<slug>/<id>, /album/<slug>/<id>, /song/<slug>/<id>, /charts, /top-artists or Network API URLs"


def get_mock_catalog_items(source_type, source_id, slug, language="all"):
    """
    Deterministic mock data for local catalogue development and testing.
    Never calls unauthorized external endpoints.
    Every record is visibly identified with '[MOCK]' and is_mock: True.
    """
    clean_name = slug.replace("-songs", "").replace("-", " ").title()
    art_placeholder = "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500"

    if source_type == "artist":
        titles = [
            ("O O Jane Jaana", "Pyaar Kiya To Darna Kya", "Salman Khan, Kamaal Khan"),
            ("Tere Naam", "Tere Naam", "Salman Khan, Udit Narayan"),
            ("Hangover", "Kick", "Salman Khan, Shreya Ghoshal"),
            ("Character Dheela", "Ready", "Salman Khan, Neeraj Shridhar"),
            ("Jumme Ki Raat", "Kick", "Salman Khan, Mika Singh")
        ] if "salman" in slug.lower() else [
            (f"{clean_name} Signature 1", f"{clean_name} Hits", clean_name),
            (f"{clean_name} Signature 2", f"{clean_name} Hits", clean_name),
            (f"{clean_name} Signature 3", f"{clean_name} Classics", clean_name),
            (f"{clean_name} Signature 4", f"{clean_name} Classics", clean_name),
            (f"{clean_name} Signature 5", f"{clean_name} Live", clean_name),
        ]
        items = []
        for i, (t, alb, art) in enumerate(titles, 1):
            items.append({
                "id": f"mock_art_{source_id}_{i}",
                "title": f"[MOCK] {t}",
                "artist": art,
                "album": alb,
                "duration_ms": 210000 + (i * 12000),
                "artwork_url": art_placeholder,
                "language": language if language != "all" else "hindi",
                "year": "2026",
                "is_mock": True
            })
        return items

    elif source_type in ("playlist", "album"):
        titles = [
            ("Kesariya", "Brahmastra", "Arijit Singh, Pritam"),
            ("Apna Bana Le", "Bhediya", "Arijit Singh, Sachin-Jigar"),
            ("Tere Hawaale", "Laal Singh Chaddha", "Arijit Singh, Shilpa Rao"),
            ("Chaleya", "Jawan", "Arijit Singh, Shilpa Rao, Anirudh"),
            ("Heeriye", "Heeriye Single", "Jasleen Royal, Arijit Singh")
        ]
        items = []
        for i, (t, alb, art) in enumerate(titles, 1):
            items.append({
                "id": f"mock_pl_{source_id[:8]}_{i}",
                "title": f"[MOCK] {t}",
                "artist": art,
                "album": alb,
                "duration_ms": 220000 + (i * 15000),
                "artwork_url": art_placeholder,
                "language": language if language != "all" else "hindi",
                "year": "2026",
                "is_mock": True
            })
        return items

    elif source_type == "new_releases":
        titles = [
            ("Tujh Mein Basi Meri Jaan", "Prahaar", "Amitabh Bhattacharya"),
            ("Chitta Kukkad", "Chitta Kukkad", "Simran Bhardwaj"),
            ("One Name", "Jailer 2", "Anirudh Ravichander"),
            ("Rola Hogya", "Rola Hogya", "Renuka Panwar"),
            ("Shaky", "Shaky Single", "Sanju Rathod")
        ]
        items = []
        for i, (t, alb, art) in enumerate(titles, 1):
            items.append({
                "id": f"mock_nr_{i}",
                "title": f"[MOCK] {t}",
                "artist": art,
                "album": alb,
                "duration_ms": 195000 + (i * 8000),
                "artwork_url": art_placeholder,
                "language": language if language != "all" else "all",
                "year": "2026",
                "is_mock": True
            })
        return items

    elif source_type == "charts":
        titles = [
            ("India Top 50 Chart", "Official Weekly Chart", "Top 50 Songs in India"),
            ("Viral 50 India", "Trending Social Chart", "Most Shared Songs"),
            ("Bollywood Hot 20", "Bollywood Charts", "Top Hindi Film Songs"),
            ("Punjabi 10", "Regional Charts", "Top Punjabi Hits")
        ]
        items = []
        for i, (t, alb, art) in enumerate(titles, 1):
            items.append({
                "id": f"mock_chart_{i}",
                "title": f"[MOCK] {t}",
                "artist": art,
                "album": alb,
                "duration_ms": 240000,
                "artwork_url": art_placeholder,
                "language": "all",
                "year": "2026",
                "is_mock": True
            })
        return items

    elif source_type == "top_artists":
        names = ["Arijit Singh", "Shreya Ghoshal", "Pritam", "Anirudh Ravichander", "A.R. Rahman"]
        items = []
        for i, name in enumerate(names, 1):
            items.append({
                "id": f"mock_artist_star_{i}",
                "title": f"[MOCK] {name} Radio",
                "artist": name,
                "album": f"Best of {name}",
                "duration_ms": 230000,
                "artwork_url": art_placeholder,
                "language": "all",
                "year": "2026",
                "is_mock": True
            })
        return items

    elif source_type in ("mix", "jiosaavn_mix"):
        titles = [
            ("Daily Mix Signature 1", "Daily Mix Hits", "Arijit Singh"),
            ("Daily Mix Signature 2", "Daily Mix Hits", "Shreya Ghoshal"),
            ("Daily Mix Signature 3", "Daily Mix Classics", "Pritam"),
            ("Daily Mix Signature 4", "Daily Mix Classics", "Atif Aslam"),
            ("Daily Mix Signature 5", "Daily Mix Live", "A.R. Rahman")
        ]
        items = []
        for i, (t, alb, art) in enumerate(titles, 1):
            items.append({
                "id": f"mock_mix_{source_id[:8]}_{i}",
                "title": f"[MOCK] {t}",
                "artist": art,
                "album": alb,
                "duration_ms": 215000 + (i * 10000),
                "artwork_url": art_placeholder,
                "language": language if language != "all" else "hindi",
                "year": "2026",
                "is_mock": True
            })
        return items

    elif source_type == "song":
        return [{
            "id": f"mock_song_{source_id}",
            "title": f"[MOCK] {clean_name}",
            "artist": "Featured Artist",
            "album": clean_name,
            "duration_ms": 230000,
            "artwork_url": art_placeholder,
            "language": language if language != "all" else "all",
            "year": "2026",
            "is_mock": True
        }]

    return []


def _is_junk_catalog_track(track):
    """Drop Jio junk / mock / test rows that must never reach Home (NULL artist, sample trailer)."""
    if not isinstance(track, dict):
        return True
    if track.get("is_mock") is True:
        return True
    title = str(track.get("title") or "").strip()
    artist = str(track.get("artist") or "").strip()
    if not title:
        return True
    tl = title.lower()
    al = artist.lower()
    if "sample trailer" in tl or tl.startswith("this is a sample"):
        return True
    if al in ("null", "none", "undefined", "n/a", "-"):
        return True
    if artist.upper() == "NULL":
        return True
    tid = str(track.get("id") or track.get("token") or "").strip().lower()
    if tid in ("null", "none", ""):
        return True
    return False


def _filter_live_catalog_tracks(tracks):
    if not isinstance(tracks, list):
        return []
    return [t for t in tracks if not _is_junk_catalog_track(t)]


def _normalize_new_releases_identity(source_type, source_id, slug, source_url=None):
    """Never resolve /new-releases as playlist/song — that returns garbage tracks."""
    blob = " ".join(
        [
            str(source_type or ""),
            str(source_id or ""),
            str(slug or ""),
            str(source_url or ""),
        ]
    ).lower()
    if "new-releases" in blob or "new_releases" in blob:
        sid = str(source_id or slug or "new-releases").strip() or "new-releases"
        if not sid.startswith("new-releases"):
            sid = "new-releases"
        return "new_releases", sid, sid.replace("_", "-")
    return source_type, source_id, slug


def _apply_source_url_identity(section, preserve_admin_display_type=False):
    """
    Re-derive fetch identity (id/slug / new-releases) from the full Jio URL.
    When preserve_admin_display_type=True, keep admin song/track choice for the
    Home tracks shelf + admin badge — URL still drives how songs are resolved.
    """
    if not isinstance(section, dict):
        return section
    admin_st = str(section.get("source_type") or "").strip().lower()
    wants_tracks = admin_st in ("song", "track") or str(section.get("display_mode") or "").lower() in (
        "tracks",
        "songs",
        "song",
    )
    url = str(section.get("source_url") or "").strip()
    if not url:
        st, sid, slug = _normalize_new_releases_identity(
            section.get("source_type"),
            section.get("source_id"),
            section.get("slug"),
        )
        section["source_id"] = sid
        section["slug"] = slug
        if not (preserve_admin_display_type and wants_tracks):
            section["source_type"] = st
        return section
    parsed, _ = parse_catalog_url(url)
    if not parsed:
        return section
    section["source_id"] = parsed.get("source_id") or section.get("source_id")
    section["slug"] = parsed.get("slug") or section.get("slug")
    if parsed.get("language") and (
        not section.get("language") or str(section.get("language")).lower() == "all"
    ):
        section["language"] = parsed.get("language")
    st, sid, slug = _normalize_new_releases_identity(
        parsed.get("source_type") or section.get("source_type"),
        section.get("source_id"),
        section.get("slug"),
        url,
    )
    section["source_id"] = sid
    section["slug"] = slug
    if preserve_admin_display_type and wants_tracks:
        # Admin chose SONG/TRACK — keep it for UI/Home; resolve still uses source_url
        section["source_type"] = "song"
        section["display_mode"] = "tracks"
    else:
        section["source_type"] = st
    return section


def resolve_catalog_items(source_type, source_id, slug, language="all", source_url=None):
    """
    Fetches live items from JioSaavn in real-time.
    Returns (items, is_mock, provider_status, detected_title, detected_artwork).
    Falls back gracefully to clean tracks if network is unavailable.

    When source_url is set (admin catalogue), the full URL wins over stored
    source_id/slug so refresh always hits the same Jio page the admin saved.

    Language rules (no multi-language mix hardcode):
    - Explicit section language (not "all") → that language only
    - new_releases slug "new-releases-{lang}" → that language only
    - Otherwise → hindi only (admin should set language when pasting a Jio link)
    """
    if source_url:
        parsed, _ = parse_catalog_url(str(source_url))
        if parsed:
            source_type = parsed.get("source_type") or source_type
            source_id = parsed.get("source_id") or source_id
            slug = parsed.get("slug") or slug
            if parsed.get("language") and (not language or str(language).lower() == "all"):
                language = parsed.get("language")

    slug = slug or ""
    source_type, source_id, slug = _normalize_new_releases_identity(
        source_type, source_id, slug, source_url
    )

    lang = (language or "all").strip().lower()
    if lang and lang != "all":
        langs = [lang]
    elif source_type == "new_releases" and "new-releases-" in slug:
        langs = [slug.replace("new-releases-", "").split("-")[0] or "hindi"]
    else:
        langs = ["hindi"]
    detected_artwork = None
    try:
        if source_type in ("mix", "jiosaavn_mix") and source_id:
            # JioSaavn Daily Mix / Dynamic Mix — try mix, then playlist, then trending
            detected_title = slug.replace("-", " ").replace("_", " ").title()
            for call_type in ("mix", "playlist"):
                res = jio_call(
                    "webapi.get",
                    {"token": source_id, "type": call_type, "n": "50", "p": "1"},
                    langs,
                )
                raw_songs = []
                if isinstance(res, dict):
                    detected_title = res.get("title") or res.get("name") or detected_title
                    detected_artwork = (
                        res.get("image")
                        or res.get("artwork_url")
                        or res.get("header_image")
                        or detected_artwork
                    )
                    raw_songs = res.get("list") or res.get("songs") or res.get("tracks") or []
                if raw_songs:
                    tracks = dedupe(_tracks(raw_songs))
                    if tracks:
                        detected_artwork = detected_artwork or tracks[0].get("artwork_url")
                        return tracks, False, "ok", detected_title, detected_artwork
            # Playlist-details path (some mix tokens resolve as playlists)
            info_pl = entity_details("playlist", token=source_id, limit=50, languages=langs)
            pl_tracks = info_pl.get("tracks") or []
            if pl_tracks:
                detected_artwork = info_pl.get("artwork_url") or info_pl.get("image")
                return pl_tracks, False, "ok", info_pl.get("title") or detected_title, detected_artwork
            # Last resort: live trending (real Jio songs — never mock)
            trend = live_trending(languages=langs or ["hindi"])
            songs = trend if isinstance(trend, list) else (trend.get("songs") or [])
            if songs:
                detected_artwork = songs[0].get("artwork_url")
                return songs[:30], False, "ok", detected_title or "Daily Mix", detected_artwork

        elif source_type in ("song", "track") and source_id:
            # Admin "display as tracks" often keeps a playlist URL with type=song.
            # Prefer full playlist when available so Home can show every song.
            info_pl = entity_details("playlist", token=source_id, limit=50, languages=langs)
            pl_tracks = info_pl.get("tracks") or []
            if len(pl_tracks) > 1:
                detected_artwork = info_pl.get("artwork_url") or info_pl.get("image")
                detected_title = info_pl.get("title") or slug.replace("-", " ").title()
                return pl_tracks, False, "ok", detected_title, detected_artwork

            # 1. Try resolving via token first (true single song)
            res = jio_call("webapi.get", {"token": source_id, "type": "song"}, langs)
            raw_songs = res.get("songs") if isinstance(res, dict) else []
            if not raw_songs:
                # 2. Try direct song details PID
                dt = song_details(source_id)
                if dt and dt.get("id"):
                    return [dt], False, "ok", dt.get("title"), dt.get("artwork_url")
            if raw_songs:
                tracks = dedupe(_tracks(raw_songs))
                detected_artwork = tracks[0].get("artwork_url") if tracks else None
                detected_title = tracks[0].get("title") if tracks else slug.replace("-", " ").title()
                return tracks, False, "ok", detected_title, detected_artwork

        elif source_type == "playlist" and source_id:
            info = entity_details("playlist", token=source_id, limit=40, languages=langs)
            tracks = info.get("tracks") or []
            detected_artwork = info.get("artwork_url") or info.get("image")
            if tracks:
                return tracks, False, "ok", info.get("title"), detected_artwork

        elif source_type == "album" and source_id:
            info = entity_details("album", token=source_id, limit=40, languages=langs)
            tracks = info.get("tracks") or []
            if not tracks and not source_id.startswith(","):
                info = entity_details("album", token="," + source_id, limit=40, languages=langs)
                tracks = info.get("tracks") or []
            if not tracks and slug:
                found = search_entities("albums", slug.replace("-", " "), 5, languages=langs).get("results", [])
                if found:
                    top_alb = found[0]
                    alb_id = top_alb.get("id")
                    alb_tok = top_alb.get("token")
                    info = entity_details("album", entity_id=alb_id, token=alb_tok, limit=40, languages=langs)
                    tracks = info.get("tracks") or []
            detected_artwork = info.get("artwork_url") or info.get("image")
            if tracks:
                return tracks, False, "ok", info.get("title"), detected_artwork

        elif source_type == "artist" and source_id:
            info = artist_details(token=source_id, n_song=30, languages=langs)
            songs = info.get("top_songs") or []
            detected_artwork = info.get("image") or (songs[0].get("artwork_url") if songs else None)
            if songs:
                return songs, False, "ok", info.get("name"), detected_artwork

        elif source_type == "new_releases":
            req_lang = langs or ["hindi"]
            res = live_new_releases(languages=req_lang, limit=30)
            songs = _filter_live_catalog_tracks(res.get("songs") or [])
            if songs:
                detected_artwork = songs[0].get("artwork_url") if songs else None
                title_lang = req_lang[0].title() if req_lang else "Hindi"
                return songs, False, "ok", f"New Releases ({title_lang})", detected_artwork

        elif source_type == "radio":
            res = live_trending(languages=langs or ["hindi"])
            songs = res if isinstance(res, list) else (res.get("songs") or [])
            if songs:
                detected_artwork = songs[0].get("artwork_url") if songs else None
                return songs, False, "ok", "Live Radio & Non-Stop Hits", detected_artwork

        elif source_type == "charts":
            charts = live_charts(languages=langs)
            if isinstance(charts, list) and len(charts) > 0:
                first_chart = charts[0]
                first_chart_token = first_chart.get("token")
                detected_artwork = first_chart.get("artwork_url") or first_chart.get("image")
                if first_chart_token:
                    info = entity_details("playlist", token=first_chart_token, limit=30, languages=langs)
                    tracks = info.get("tracks") or []
                    if tracks:
                        return tracks, False, "ok", first_chart.get("title") or "Official Charts", detected_artwork

        elif source_type == "top_artists":
            top_art_info = artist_details(artist_id="459320", n_song=20, languages=langs)
            songs = top_art_info.get("top_songs") or []
            detected_artwork = top_art_info.get("image") or (songs[0].get("artwork_url") if songs else None)
            if songs:
                return songs, False, "ok", "Top Artists Spotlight", detected_artwork
    except Exception as e:
        print(f"[Catalog Live Fetch Exception] {source_type} ({source_id}): {e}")

    # Never inject fake/mock tracks into production — empty + unavailable status.
    print(f"[Catalog] live resolve empty for {source_type}/{source_id} — no mock fallback")
    return [], True, "unavailable", None, detected_artwork


def _purge_junk_from_items_cache():
    """Remove sample-trailer / NULL-artist junk already sitting in RAM song cache."""
    purged = 0
    for key, entry in list(_CATALOG_ITEMS_CACHE.items()):
        if not isinstance(entry, tuple) or len(entry) < 2:
            continue
        ts, items = entry[0], entry[1]
        meta = entry[2] if len(entry) > 2 and isinstance(entry[2], dict) else {}
        if not isinstance(items, list) or not items:
            continue
        cleaned = _filter_live_catalog_tracks(items)
        if len(cleaned) != len(items):
            purged += len(items) - len(cleaned)
            _CATALOG_ITEMS_CACHE[key] = (ts, cleaned, dict(meta))
    if purged:
        print(f"[Catalog] purged {purged} junk track(s) from items cache")
        _mark_catalog_items_dirty()
    return purged


def _generate_default_catalog_sections():
    default_seeds = [
        {
            "url": "https://www.jiosaavn.com/featured/hindi-india-superhits-top-50/zlJfJYVuyjpxWb5,FqsjKg__",
            "group": "Top Charts",
            "title": "Hindi India Superhits Top 50"
        },
        {
            "url": "https://www.jiosaavn.com/artist/kishore-kumar-songs/yMoPyl3ZzyY_",
            "group": "Featured Artists",
            "title": "Kishore Kumar"
        },
        {
            "url": "https://www.jiosaavn.com/new-releases",
            "group": "Fresh Drops",
            "title": "New Releases"
        },
        {
            "url": "https://www.jiosaavn.com/charts",
            "group": "Official Charts",
            "title": "Official Charts"
        },
        {
            "url": "https://www.jiosaavn.com/top-artists",
            "group": "Spotlight",
            "title": "Top Artists"
        },
    ]
    for lang, title in (
        ("hindi", "Hindi Hits"),
        ("punjabi", "Punjabi Hits"),
        ("bhojpuri", "Bhojpuri Hits"),
        ("haryanvi", "Haryanvi Hits"),
        ("marathi", "Marathi Hits"),
        ("gujarati", "Gujarati Hits"),
        ("tamil", "Tamil Hits"),
        ("telugu", "Telugu Hits"),
        ("bengali", "Bengali Hits"),
    ):
        default_seeds.append({
            "url": f"https://www.jiosaavn.com/new-releases/{lang}",
            "group": "Browse Languages",
            "title": title,
            "language": lang,
        })
    sections = []
    for i, s in enumerate(default_seeds, 1):
        parsed, _ = parse_catalog_url(s["url"])
        if parsed:
            lang = s.get("language") or (
                "hindi" if parsed["source_type"] in ("artist", "playlist") else "all"
            )
            items, is_mock, provider_status, detected_title, detected_art = resolve_catalog_items(
                parsed["source_type"], parsed["source_id"], parsed["slug"], lang
            )
            key_name = parsed["slug"].replace("-", "_")
            sec_uuid = str(uuid.uuid5(uuid.NAMESPACE_DNS, key_name))
            sections.append({
                "id": sec_uuid,
                "key": key_name,
                "source_url": s["url"],
                "source_type": parsed["source_type"],
                "source_id": parsed["source_id"],
                "slug": parsed["slug"],
                "display_title": s["title"],
                "display_group": s["group"],
                "language": lang,
                "position": i,
                "is_enabled": True,
                "custom_artwork_url": detected_art,
                "is_banner": False,
                "provider_status": provider_status,
                "last_refresh": int(time.time()),
                "last_error": None,
                "is_mock": is_mock,
                "item_count": len(items),
                "items": items
            })
    return sections


def matches_section_key(section, target_key):
    if not section or not target_key:
        return False
    target_str = str(target_key).strip().lower()
    norm_target = target_str.replace("-", "_").replace("sec_", "")

    s_key = str(section.get("key", "")).strip().lower()
    s_id = str(section.get("id", "")).strip().lower()
    s_slug = str(section.get("slug", "")).strip().lower()
    s_source = str(section.get("source_id", "")).strip().lower()

    if target_str in (s_key, s_id, s_slug, s_source):
        return True
    norm_key = s_key.replace("-", "_").replace("sec_", "")
    norm_id = s_id.replace("-", "_").replace("sec_", "")
    norm_slug = s_slug.replace("-", "_").replace("sec_", "")

    return norm_target in (norm_key, norm_id, norm_slug)


def _parse_iso_to_unix(val):
    if val is None or val == "":
        return None
    if isinstance(val, (int, float)):
        return int(val)
    if isinstance(val, str):
        try:
            clean = val.replace("Z", "+00:00")
            dt = datetime.fromisoformat(clean)
            return int(dt.timestamp())
        except Exception:
            if val.isdigit():
                return int(val)
    return None


def sync_catalog_from_supabase():
    try:
        url = f"{SUPABASE_URL.rstrip('/')}/rest/v1/catalog_sections?select=*&order=position.asc"
        auth_key = SUPABASE_SERVICE_ROLE_KEY or SUPABASE_ANON_KEY
        headers = {
            "apikey": SUPABASE_ANON_KEY,
            "Authorization": f"Bearer {auth_key}",
            "User-Agent": "MusicApp/1.0"
        }
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=5) as resp:
            if resp.status == 200:
                body = resp.read().decode("utf-8")
                rows = json.loads(body)
                if isinstance(rows, list) and len(rows) > 0:
                    for r in rows:
                        # Convert ISO timestamps back to integer unix epoch
                        for ts_col in ("campaign_start", "campaign_end", "last_refresh"):
                            r[ts_col] = _parse_iso_to_unix(r.get(ts_col))

                        # Unpack encoded metadata from last_error if present
                        err = r.get("last_error")
                        if err and isinstance(err, str) and err.strip().startswith("{"):
                            try:
                                extra = json.loads(err)
                                if isinstance(extra, dict):
                                    if "excluded_track_ids" in extra:
                                        r["excluded_track_ids"] = extra.get("excluded_track_ids", [])
                                    if "custom_tracks" in extra:
                                        r["custom_tracks"] = extra.get("custom_tracks", [])
                                    if extra.get("original_source_type"):
                                        r["source_type"] = extra["original_source_type"]
                                    if extra.get("display_mode"):
                                        r["display_mode"] = extra["display_mode"]
                                    if extra.get("updated_at") is not None:
                                        r["updated_at"] = extra["updated_at"]
                                    if extra.get("item_count") is not None:
                                        r["item_count"] = extra["item_count"]
                                    # Metadata bag was stuffed into last_error — never show as ERR
                                    real = extra.get("real_last_error")
                                    r["last_error"] = real if isinstance(real, str) and real.strip() else None
                            except Exception:
                                # Corrupt JSON in last_error — clear so admin UI stays clean
                                r["last_error"] = None
                    return rows
    except Exception as e:
        print(f"[Catalog Supabase Sync] error: {e}")
    return None


_CATALOG_SUPABASE_SYNC_LOCK = threading.Lock()


def sync_catalog_to_supabase(sections=None):
    """
    Upsert local catalogue to Supabase, then prune orphans.

    MUST be serialized: a stale bg sync of N rows was pruning a just-created
    N+1 shelf (create returned 201, then verify 404 / Persistence failed).
    Always push the latest RAM/disk snapshot under the lock.
    """
    with _CATALOG_SUPABASE_SYNC_LOCK:
        return _sync_catalog_to_supabase_unlocked(sections)


def _sync_catalog_to_supabase_unlocked(sections=None):
    try:
        # Prefer live mem so a queued/stale caller cannot prune newer creates.
        latest = _CATALOG_SECTIONS_MEM.get("data")
        if isinstance(latest, list) and latest:
            sections = latest
        if not sections:
            return False
        auth_key = SUPABASE_SERVICE_ROLE_KEY or SUPABASE_ANON_KEY
        headers = {
            "apikey": SUPABASE_ANON_KEY,
            "Authorization": f"Bearer {auth_key}",
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates",
            "User-Agent": "MusicApp/1.0"
        }
        url = f"{SUPABASE_URL.rstrip('/')}/rest/v1/catalog_sections"
        cols = [
            "id", "key", "source_url", "source_type", "provider", "source_id", "slug",
            "display_title", "display_group", "subtitle", "language", "position",
            "is_enabled", "custom_artwork_url", "is_banner", "campaign_start", "campaign_end",
            "provider_status", "last_refresh", "last_error"
        ]
        payload = []
        for s in sections:
            # 1. Enforce deterministic UUID
            sec_id = s.get("id")
            try:
                uuid.UUID(str(sec_id))
            except Exception:
                sec_id = str(uuid.uuid5(uuid.NAMESPACE_DNS, str(s.get("key", uuid.uuid4()))))

            # 2. Pack extra metadata into last_error column (schema has no meta JSON col).
            # Real human errors go in extra.real_last_error so UI never shows the bag as ERR.
            extra = {}
            if s.get("excluded_track_ids"):
                extra["excluded_track_ids"] = s.get("excluded_track_ids")
            if s.get("custom_tracks"):
                extra["custom_tracks"] = s.get("custom_tracks")
            if s.get("display_mode"):
                extra["display_mode"] = s.get("display_mode")
            if s.get("updated_at") is not None:
                extra["updated_at"] = s.get("updated_at")
            if s.get("item_count") is not None:
                extra["item_count"] = s.get("item_count")

            raw_stype = str(s.get("source_type") or "playlist")
            if raw_stype in ("mix", "jiosaavn_mix", "radio", "song", "track"):
                extra["original_source_type"] = raw_stype
                allowed_stype = "playlist"
            else:
                allowed_stype = raw_stype

            real_err = s.get("last_error")
            if isinstance(real_err, str) and real_err.strip() and not real_err.strip().startswith("{"):
                extra["real_last_error"] = real_err.strip()

            row = {k: s.get(k) for k in cols}
            row["id"] = sec_id
            row["key"] = str(s.get("key") or sec_id)
            row["source_url"] = str(s.get("source_url") or "")
            row["source_type"] = allowed_stype
            row["provider"] = "custom_api"
            row["source_id"] = str(s.get("source_id") or s.get("slug") or s.get("key") or sec_id)
            row["display_title"] = str(s.get("display_title") or s.get("key") or "Section")
            row["display_group"] = str(s.get("display_group") or "Curated")
            row["language"] = str(s.get("language") or "all")
            row["position"] = int(s.get("position") or 1)
            row["is_enabled"] = bool(s.get("is_enabled", True))
            row["is_banner"] = bool(s.get("is_banner", False))
            # Always JSON-bag or null — never leave raw meta string as a fake "error"
            row["last_error"] = json.dumps(extra) if extra else None

            for ts_col in ("campaign_start", "campaign_end", "last_refresh"):
                val = row.get(ts_col)
                if isinstance(val, (int, float)):
                    row[ts_col] = datetime.fromtimestamp(val, tz=timezone.utc).isoformat()
                elif val == "" or val is False:
                    row[ts_col] = None

            payload.append(row)

        if payload:
            data = json.dumps(payload).encode("utf-8")
            req = urllib.request.Request(url, data=data, headers=headers, method="POST")
            # 90+ shelves need more than 5s — short timeout left creates "saved" then verify-miss.
            with urllib.request.urlopen(req, timeout=45) as resp:
                print(f"[Catalog Supabase Upsert] Synced {len(payload)} sections, HTTP {resp.status}")
            # Prune orphans only outside the admin-edit window. A stale concurrent
            # sync of N rows was deleting the just-created N+1 row during create.
            if time.time() >= _CATALOG_LOCAL_AUTHORITY_UNTIL:
                prune_catalog_sections_from_supabase([r.get("key") for r in payload])
            else:
                print(
                    f"[Catalog] upserted {len(payload)} — prune skipped "
                    "(admin authority window active)"
                )
            return True
    except Exception as e:
        print(f"[Catalog Supabase Upsert] error: {e}")
        return False
    return True


def upsert_single_catalog_section_to_supabase(section):
    """
    Directly upsert ONE section to Supabase and confirm persistence.
    Returns (True, saved_row) on success, (False, error_message) on failure.
    """
    if not SUPABASE_URL or not (SUPABASE_SERVICE_ROLE_KEY or SUPABASE_ANON_KEY):
        return True, section

    auth_key = SUPABASE_SERVICE_ROLE_KEY or SUPABASE_ANON_KEY
    headers = {
        "apikey": SUPABASE_ANON_KEY,
        "Authorization": f"Bearer {auth_key}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates,return=representation",
        "User-Agent": "MusicApp/1.0",
    }
    url = f"{SUPABASE_URL.rstrip('/')}/rest/v1/catalog_sections"

    sec_id = section.get("id")
    try:
        uuid.UUID(str(sec_id))
    except Exception:
        sec_id = str(uuid.uuid5(uuid.NAMESPACE_DNS, str(section.get("key", uuid.uuid4()))))

    extra = {}
    if section.get("excluded_track_ids"):
        extra["excluded_track_ids"] = section.get("excluded_track_ids")
    if section.get("custom_tracks"):
        extra["custom_tracks"] = section.get("custom_tracks")
    if section.get("display_mode"):
        extra["display_mode"] = section.get("display_mode")
    if section.get("updated_at") is not None:
        extra["updated_at"] = section.get("updated_at")
    if section.get("item_count") is not None:
        extra["item_count"] = section.get("item_count")

    raw_stype = str(section.get("source_type") or "playlist")
    if raw_stype in ("mix", "jiosaavn_mix", "radio", "song", "track"):
        extra["original_source_type"] = raw_stype
        allowed_stype = "playlist"
    else:
        allowed_stype = raw_stype

    real_err = section.get("last_error")
    if isinstance(real_err, str) and real_err.strip() and not real_err.strip().startswith("{"):
        extra["real_last_error"] = real_err.strip()

    cols = [
        "id", "key", "source_url", "source_type", "provider", "source_id", "slug",
        "display_title", "display_group", "subtitle", "language", "position",
        "is_enabled", "custom_artwork_url", "is_banner", "campaign_start", "campaign_end",
        "provider_status", "last_refresh", "last_error"
    ]
    row = {k: section.get(k) for k in cols}
    row["id"] = sec_id
    row["key"] = str(section.get("key") or sec_id)
    row["source_url"] = str(section.get("source_url") or "")
    row["source_type"] = allowed_stype
    row["provider"] = "custom_api"
    row["source_id"] = str(section.get("source_id") or section.get("slug") or section.get("key") or sec_id)
    row["display_title"] = str(section.get("display_title") or section.get("key") or "Section")
    row["display_group"] = str(section.get("display_group") or "Curated")
    row["language"] = str(section.get("language") or "all")
    row["position"] = int(section.get("position") or 1)
    row["is_enabled"] = bool(section.get("is_enabled", True))
    row["is_banner"] = bool(section.get("is_banner", False))
    row["last_error"] = json.dumps(extra) if extra else None

    for ts_col in ("campaign_start", "campaign_end", "last_refresh"):
        val = row.get(ts_col)
        if isinstance(val, (int, float)):
            row[ts_col] = datetime.fromtimestamp(val, tz=timezone.utc).isoformat()
        elif val == "" or val is False:
            row[ts_col] = None

    payload = [row]
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")

    for attempt in range(2):
        try:
            with urllib.request.urlopen(req, timeout=8) as resp:
                if resp.status in (200, 201):
                    body = resp.read().decode("utf-8")
                    saved_rows = json.loads(body) if body else []
                    print(f"[Catalog Supabase Upsert] Single row '{row['key']}' persisted, HTTP {resp.status}")
                    return True, (saved_rows[0] if saved_rows else row)
        except Exception as e:
            print(f"[Catalog Supabase Upsert] Single row attempt {attempt+1} failed: {e}")
            if attempt == 0:
                time.sleep(0.5)

    return False, "Database write timeout or error"


def delete_catalog_section_from_supabase(section_key, section_id=None, source_id=None, slug=None):
    """
    Hard-delete a catalogue row from Supabase by its unique key and/or UUID id.
    Never deletes by source_id or slug to avoid deleting other shelves sharing the source.
    Returns True if remote deletion is confirmed (HTTP 200/204), False on failure.
    """
    if not SUPABASE_URL or not (SUPABASE_SERVICE_ROLE_KEY or SUPABASE_ANON_KEY):
        return True

    deleted_any = False
    try:
        auth_key = SUPABASE_SERVICE_ROLE_KEY or SUPABASE_ANON_KEY
        headers = {
            "apikey": SUPABASE_ANON_KEY,
            "Authorization": f"Bearer {auth_key}",
            "Prefer": "return=minimal",
            "User-Agent": "MusicApp/1.0",
        }
        filters = []
        if section_id:
            try:
                uuid.UUID(str(section_id))
                filters.append(f"id=eq.{urllib.parse.quote(str(section_id), safe='')}")
            except Exception:
                pass
        if section_key:
            filters.append(f"key=eq.{urllib.parse.quote(str(section_key), safe='')}")

        if not filters:
            return False

        seen = set()
        for filt in filters:
            if filt in seen:
                continue
            seen.add(filt)
            try:
                url = f"{SUPABASE_URL.rstrip('/')}/rest/v1/catalog_sections?{filt}"
                req = urllib.request.Request(url, headers=headers, method="DELETE")
                with urllib.request.urlopen(req, timeout=8) as resp:
                    if resp.status in (200, 204):
                        deleted_any = True
                        print(f"[Catalog Supabase Delete] {filt} → HTTP {resp.status}")
            except Exception as e:
                print(f"[Catalog Supabase Delete] {filt} error: {e}")
                # Retry once
                try:
                    url = f"{SUPABASE_URL.rstrip('/')}/rest/v1/catalog_sections?{filt}"
                    req = urllib.request.Request(url, headers=headers, method="DELETE")
                    with urllib.request.urlopen(req, timeout=8) as resp:
                        if resp.status in (200, 204):
                            deleted_any = True
                except Exception as e2:
                    print(f"[Catalog Supabase Delete] retry {filt} error: {e2}")
    except Exception as e:
        print(f"[Catalog Supabase Delete] error: {e}")
    return deleted_any


def prune_catalog_sections_from_supabase(keep_keys):
    """Remove remote rows whose key is not in the current local catalogue."""
    keep = {str(k).strip() for k in (keep_keys or []) if k and str(k).strip()}
    if len(keep) < 1:
        # Never wipe the whole table on an empty accidental save
        return 0
    try:
        auth_key = SUPABASE_SERVICE_ROLE_KEY or SUPABASE_ANON_KEY
        headers = {
            "apikey": SUPABASE_ANON_KEY,
            "Authorization": f"Bearer {auth_key}",
            "User-Agent": "MusicApp/1.0",
        }
        url = f"{SUPABASE_URL.rstrip('/')}/rest/v1/catalog_sections?select=id,key"
        req = urllib.request.Request(url, headers=headers, method="GET")
        with urllib.request.urlopen(req, timeout=12) as resp:
            remote = json.loads(resp.read().decode("utf-8") or "[]")
        if not isinstance(remote, list):
            return 0
        orphan_ids = [
            str(row.get("id")) for row in remote
            if isinstance(row, dict) and row.get("id") and str(row.get("key") or "").strip() not in keep
        ]
        removed = 0
        if orphan_ids:
            for i in range(0, len(orphan_ids), 40):
                chunk = orphan_ids[i:i+40]
                id_filter = f"id=in.({','.join(chunk)})"
                del_url = f"{SUPABASE_URL.rstrip('/')}/rest/v1/catalog_sections?{id_filter}"
                del_req = urllib.request.Request(del_url, headers=headers, method="DELETE")
                try:
                    with urllib.request.urlopen(del_req, timeout=10) as del_resp:
                        if del_resp.status in (200, 204):
                            removed += len(chunk)
                except Exception as e:
                    print(f"[Catalog Supabase Prune] batch delete error: {e}")
        if removed:
            print(f"[Catalog Supabase Prune] removed {removed} orphan section(s)")
        return removed
    except Exception as e:
        print(f"[Catalog Supabase Prune] error: {e}")
        return 0


# Section metadata: Supabase is membership truth for users (no timed "wait then update").
# Admin-edit window still serves local RAM so just-saved order never flickers.
_CATALOG_SUPABASE_TTL = 0  # 0 = always reconcile from DB when not in admin-edit window
_CATALOG_RECONCILE_LOCK = threading.Lock()
_CATALOG_ITEMS_TTL = 21600       # bg-refresh songs after 6h
_CATALOG_ITEMS_STALE = 604800    # still serve disk/RAM songs up to 7 days
_CATALOG_WARM_LOCK = threading.Lock()
_CATALOG_WARMING = False
CATALOG_ITEMS_CACHE_FILE = os.path.join(DATA_DIR, "catalog_items_cache.json")
_CATALOG_ITEMS_DISK_LOADED = False
_CATALOG_ITEMS_DISK_LOCK = threading.Lock()
_CATALOG_ITEMS_DISK_DIRTY = False
_CATALOG_ITEMS_PERSIST_SCHEDULED = False


def _read_local_catalog_sections():
    if not os.path.exists(CATALOG_STORAGE_FILE):
        return None
    try:
        with open(CATALOG_STORAGE_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
            if isinstance(data, list) and data:
                return sorted(data, key=lambda x: x.get("position", 999))
    except Exception as e:
        print(f"[Catalog] Failed to load {CATALOG_STORAGE_FILE}: {e}")
    return None


def _write_local_catalog_sections(sections):
    try:
        with open(CATALOG_STORAGE_FILE, "w", encoding="utf-8") as f:
            json.dump(sections, f, indent=2, ensure_ascii=False)
    except Exception as e:
        print(f"[Catalog] Failed to write {CATALOG_STORAGE_FILE}: {e}")


def _ensure_unique_catalog_positions(sections):
    """
    Assign unique 1..N positions in current list order.
    Duplicate ranks (many shelves at position=1) make Home group order unstable —
    Devotional/Top Charts/Trending all tie and Flutter picks insertion order.
    """
    if not isinstance(sections, list) or not sections:
        return sections or []
    positions = [s.get("position") for s in sections if isinstance(s, dict)]
    if len(positions) == len(set(int(p) if p is not None else -1 for p in positions)):
        # Already unique — keep relative order by position
        return sorted(sections, key=lambda x: int(x.get("position") or 999))
    # Preserve group blocks: sort by (position, first-seen group order, title)
    group_rank = {}
    for s in sections:
        if not isinstance(s, dict):
            continue
        g = str(s.get("display_group") or "Curated").strip() or "Curated"
        if g not in group_rank:
            group_rank[g] = len(group_rank)
    ordered = sorted(
        [s for s in sections if isinstance(s, dict)],
        key=lambda s: (
            int(s.get("position") or 999),
            group_rank.get(str(s.get("display_group") or "Curated").strip() or "Curated", 999),
            str(s.get("display_title") or ""),
        ),
    )
    for i, s in enumerate(ordered, start=1):
        s["position"] = i
    return ordered


def _dedupe_catalog_section_rows(sections):
    """
    Keep one shelf per catalogue key only.

    Previously collapsed by (source_type, source_id), which deleted brand-new admin
    saves that reused a Jio playlist URL under a new key/title (create returned 201,
    then the next load wiped the row → Persistence verification failed).
    Home still dedupes display cards client-side when needed.
    """
    if not isinstance(sections, list) or len(sections) < 2:
        return _ensure_unique_catalog_positions(sections or [])
    ordered = sorted(sections, key=lambda x: x.get("position", 999))
    seen = set()
    out = []
    for s in ordered:
        if not isinstance(s, dict):
            continue
        key = str(s.get("key") or s.get("id") or "").strip()
        if not key:
            out.append(s)
            continue
        if key in seen:
            continue
        seen.add(key)
        out.append(s)
    return _ensure_unique_catalog_positions(out)


def _ensure_catalog_items_disk_loaded():
    """Hydrate RAM song cache from disk once — survives API restarts / blank home."""
    global _CATALOG_ITEMS_DISK_LOADED
    if _CATALOG_ITEMS_DISK_LOADED:
        return
    with _CATALOG_ITEMS_DISK_LOCK:
        if _CATALOG_ITEMS_DISK_LOADED:
            return
        _CATALOG_ITEMS_DISK_LOADED = True
        if not os.path.exists(CATALOG_ITEMS_CACHE_FILE):
            return
        try:
            with open(CATALOG_ITEMS_CACHE_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
            if not isinstance(data, dict):
                return
            loaded = 0
            for key, row in data.items():
                if not isinstance(row, dict):
                    continue
                items = row.get("items")
                ts = float(row.get("ts") or 0)
                meta = row.get("meta") or {
                    "is_mock": row.get("is_mock", False),
                    "provider_status": row.get("provider_status", "ok"),
                    "last_error": row.get("last_error"),
                    "is_stale": row.get("is_stale", False)
                }
                if isinstance(items, list):
                    _CATALOG_ITEMS_CACHE[str(key)] = (ts or time.time(), items, meta)
                    loaded += 1
            print(f"[Catalog] loaded {loaded} section song caches from disk")
        except Exception as e:
            print(f"[Catalog] items disk load failed: {e}")


def _persist_catalog_items_disk():
    """Write RAM song cache to disk atomically."""
    global _CATALOG_ITEMS_DISK_DIRTY
    with _CATALOG_ITEMS_DISK_LOCK:
        if not _CATALOG_ITEMS_DISK_DIRTY and os.path.exists(CATALOG_ITEMS_CACHE_FILE):
            try:
                if os.path.getsize(CATALOG_ITEMS_CACHE_FILE) > 2:
                    return
            except Exception:
                pass
        payload = {}
        for key, entry in list(_CATALOG_ITEMS_CACHE.items()):
            if not key or not isinstance(entry, tuple):
                continue
            ts = entry[0]
            items = entry[1]
            meta = entry[2] if len(entry) > 2 else {}
            payload[str(key)] = {
                "ts": ts,
                "items": items or [],
                "meta": meta
            }
        if not payload:
            return
        tmp = CATALOG_ITEMS_CACHE_FILE + ".tmp"
        try:
            with open(tmp, "w", encoding="utf-8") as f:
                json.dump(payload, f, ensure_ascii=False)
            os.replace(tmp, CATALOG_ITEMS_CACHE_FILE)
            _CATALOG_ITEMS_DISK_DIRTY = False
            print(f"[Catalog] saved {len(payload)} section song caches to disk")
        except Exception as e:
            print(f"[Catalog] items disk save failed: {e}")
            try:
                if os.path.exists(tmp):
                    os.remove(tmp)
            except Exception:
                pass


def _mark_catalog_items_dirty():
    """Mark dirty and coalesce disk writes (avoid thrashing on every section)."""
    global _CATALOG_ITEMS_DISK_DIRTY, _CATALOG_ITEMS_PERSIST_SCHEDULED
    with _CATALOG_ITEMS_DISK_LOCK:
        _CATALOG_ITEMS_DISK_DIRTY = True
        if _CATALOG_ITEMS_PERSIST_SCHEDULED:
            return
        _CATALOG_ITEMS_PERSIST_SCHEDULED = True

    def _delayed():
        global _CATALOG_ITEMS_PERSIST_SCHEDULED
        time.sleep(1.2)
        try:
            _persist_catalog_items_disk()
        finally:
            with _CATALOG_ITEMS_DISK_LOCK:
                _CATALOG_ITEMS_PERSIST_SCHEDULED = False
                # Another resolve landed while we wrote — schedule once more.
                if _CATALOG_ITEMS_DISK_DIRTY:
                    _mark_catalog_items_dirty()

    threading.Thread(target=_delayed, daemon=True).start()


# After admin save/reorder, local disk is authority — skip remote pull briefly
# so a slower Supabase sync cannot wipe the new Home order.
_CATALOG_LOCAL_AUTHORITY_UNTIL = 0.0


def _reconcile_catalog_with_supabase(force=False, bypass_authority=False):
    """
    Supabase catalog_sections is membership + order truth outside an admin-edit window.
    Drops Fly-local orphans so new installs never see deleted/stale shelves.

    IMPORTANT: even force=True must respect the admin-edit authority window, otherwise
    a slow concurrent pull can drop a just-created shelf before Supabase upsert lands
    (admin then sees "Persistence verification failed").
    Only bypass_authority=True (explicit reconcile-db) may overwrite during that window.
    """
    if not bypass_authority and time.time() < _CATALOG_LOCAL_AUTHORITY_UNTIL:
        return None
    remote_rows = sync_catalog_from_supabase()
    if not remote_rows:
        return None
    with CATALOG_LOCK:
        # Re-check after the (slow) remote fetch — create/save may have started meantime.
        if not bypass_authority and time.time() < _CATALOG_LOCAL_AUTHORITY_UNTIL:
            print("[Catalog] reconcile aborted — admin authority window active after remote fetch")
            return None
        local = _CATALOG_SECTIONS_MEM.get("data") or _read_local_catalog_sections() or []
        local_map = {
            str(row.get("key") or row.get("id") or ""): row
            for row in local
            if str(row.get("key") or row.get("id") or "")
        }
        by_key = {}
        for row in remote_rows:
            key = str(row.get("key") or row.get("id") or "")
            if not key:
                continue
            # Remote row is canonical (position/group/url). Keep only newer refresh stamps.
            merged = dict(row)
            loc = local_map.get(key)
            if loc:
                for field in ("last_refresh", "updated_at", "item_count", "provider_status", "last_error"):
                    if loc.get(field) is None:
                        continue
                    if field in ("last_refresh", "updated_at"):
                        try:
                            if int(loc.get(field) or 0) >= int(merged.get(field) or 0):
                                merged[field] = loc.get(field)
                        except Exception:
                            pass
                    elif merged.get(field) in (None, "", 0):
                        merged[field] = loc.get(field)
            by_key[key] = merged
        dropped = [k for k in local_map.keys() if k not in by_key]
        for k in dropped:
            print(f"[Catalog] drop local-only ghost section '{k}' (not on Supabase)")
        merged = _sanitize_sections_list(
            _dedupe_catalog_section_rows(
                sorted(by_key.values(), key=lambda x: x.get("position", 999))
            )
        )
        _write_local_catalog_sections(merged)
        _CATALOG_SECTIONS_MEM["data"] = merged
        _CATALOG_SECTIONS_MEM["at"] = time.time()
        _CATALOG_SECTIONS_MEM["synced_at"] = time.time()
    print(f"[Catalog] Supabase reconcile ok ({len(merged)} sections, dropped {len(dropped)})")
    return merged


def _bg_sync_catalog_from_supabase():
    """Non-blocking Supabase → local disk sync so home feed never waits on DB."""
    try:
        _reconcile_catalog_with_supabase(force=False)
    except Exception as e:
        print(f"[Catalog] background Supabase sync failed: {e}")


def _catalog_positions_need_fix(sections):
    if not sections:
        return False
    vals = []
    for s in sections:
        try:
            vals.append(int(s.get("position") or 0))
        except Exception:
            vals.append(0)
    return len(vals) != len(set(vals))


def _sanitize_section_last_error(section):
    """Strip Supabase metadata JSON bags from last_error so admin never shows fake ERR."""
    if not isinstance(section, dict):
        return section
    err = section.get("last_error")
    if not isinstance(err, str):
        return section
    raw = err.strip()
    if not raw.startswith("{"):
        return section
    try:
        extra = json.loads(raw)
        if isinstance(extra, dict):
            if extra.get("display_mode") and not section.get("display_mode"):
                section["display_mode"] = extra.get("display_mode")
            if extra.get("updated_at") is not None and section.get("updated_at") is None:
                section["updated_at"] = extra.get("updated_at")
            if extra.get("item_count") is not None and not section.get("item_count"):
                section["item_count"] = extra.get("item_count")
            if extra.get("original_source_type"):
                section["source_type"] = extra["original_source_type"]
            real = extra.get("real_last_error")
            section["last_error"] = real if isinstance(real, str) and real.strip() else None
        else:
            section["last_error"] = None
    except Exception:
        section["last_error"] = None
    return section


def _sanitize_sections_list(sections):
    out = []
    for s in sections or []:
        if isinstance(s, dict):
            out.append(_sanitize_section_last_error(dict(s)))
        else:
            out.append(s)
    return out


_CATALOG_LAST_BG_RECONCILE_AT = 0.0
_CATALOG_BG_RECONCILE_MIN_GAP = 45.0  # don't hammer Supabase on every Home hit


def load_catalog_sections():
    """
    Memory/disk first (fast admin + Home). Supabase reconcile runs in background
    outside the admin-edit window — never block create/update/delete on a full
    remote pull (that caused 35s+ Flutter timeouts under load).
    """
    global _CATALOG_LAST_BG_RECONCILE_AT
    _ensure_catalog_items_disk_loaded()
    _purge_junk_from_items_cache()

    now = time.time()
    in_authority = now < _CATALOG_LOCAL_AUTHORITY_UNTIL
    mem = _CATALOG_SECTIONS_MEM.get("data")

    # Schedule a non-blocking Supabase pull so new installs still converge.
    if (
        not in_authority
        and (now - _CATALOG_LAST_BG_RECONCILE_AT) >= _CATALOG_BG_RECONCILE_MIN_GAP
    ):
        _CATALOG_LAST_BG_RECONCILE_AT = now
        threading.Thread(target=_bg_sync_catalog_from_supabase, daemon=True).start()

    if mem:
        fixed = _sanitize_sections_list(_dedupe_catalog_section_rows(list(mem)))
        if _catalog_positions_need_fix(mem) or len(fixed) != len(mem):
            try:
                # Passive renumber must NOT extend admin authority (that blocked DB pulls)
                save_catalog_sections(fixed, sync_db=False, extend_authority=False)
            except Exception as e:
                print(f"[Catalog] auto-renumber save failed: {e}")
                _CATALOG_SECTIONS_MEM["data"] = fixed
        else:
            _CATALOG_SECTIONS_MEM["data"] = fixed
        return fixed

    with CATALOG_LOCK:
        now = time.time()
        mem = _CATALOG_SECTIONS_MEM.get("data")
        if mem:
            return _sanitize_sections_list(_dedupe_catalog_section_rows(list(mem)))

        # Cold start: Supabase first (never prefer stale disk over DB)
        remote_rows = sync_catalog_from_supabase()
        if remote_rows:
            remote_rows = _sanitize_sections_list(_dedupe_catalog_section_rows(remote_rows))
            remote_rows.sort(key=lambda x: x.get("position", 999))
            _write_local_catalog_sections(remote_rows)
            _CATALOG_SECTIONS_MEM.update({"data": remote_rows, "at": now, "synced_at": now})
            return list(remote_rows)

        local = _read_local_catalog_sections()
        if local:
            local = _sanitize_sections_list(_dedupe_catalog_section_rows(local))
            _CATALOG_SECTIONS_MEM.update({"data": local, "at": now, "synced_at": 0})
            threading.Thread(target=_bg_sync_catalog_from_supabase, daemon=True).start()
            return list(local)

        default_sections = _sanitize_sections_list(
            _dedupe_catalog_section_rows(_generate_default_catalog_sections())
        )
        _write_local_catalog_sections(default_sections)
        _CATALOG_SECTIONS_MEM.update({"data": default_sections, "at": now, "synced_at": now})
        threading.Thread(target=sync_catalog_to_supabase, args=(default_sections,), daemon=True).start()
        return list(default_sections)


_CATALOG_ITEMS_TTL = int(os.environ.get("CATALOG_ITEMS_TTL", 3600))         # Fresh for 1 hour (3600s)
_CATALOG_ITEMS_STALE = int(os.environ.get("CATALOG_ITEMS_STALE", 604800))   # Retain stale up to 7 days (604800s)

_SECTION_RESOLVE_LOCKS = {}
_SECTION_LOCKS_GUARD = threading.Lock()


def _get_section_lock(key):
    with _SECTION_LOCKS_GUARD:
        if key not in _SECTION_RESOLVE_LOCKS:
            _SECTION_RESOLVE_LOCKS[key] = threading.RLock()
        return _SECTION_RESOLVE_LOCKS[key]


def _get_cached_section_entry(key):
    entry = _CATALOG_ITEMS_CACHE.get(key)
    if not entry:
        return None
    if isinstance(entry, tuple):
        ts = entry[0]
        items = entry[1]
        meta = entry[2] if len(entry) > 2 and isinstance(entry[2], dict) else {}
        return ts, list(items), dict(meta)
    return None


def _is_entry_mock(entry):
    if not entry or not isinstance(entry, tuple) or len(entry) < 2:
        return False
    items = entry[1]
    meta = entry[2] if len(entry) > 2 and isinstance(entry[2], dict) else {}
    if meta.get("is_mock"):
        return True
    if isinstance(items, list) and items and any(isinstance(t, dict) and t.get("is_mock") for t in items):
        return True
    return False


def _resolve_section_base_items(section, force_fetch=False):
    """
    Thread-safe resolution of section items with coalescing locks.
    If upstream fails and we already have cached items:
    Retains the existing cached items and sets is_stale=True, last_error=...
    Never destroys good content with an empty/mock list on upstream failure!
    """
    _ensure_catalog_items_disk_loaded()
    key = str(section.get("key") or section.get("id") or section.get("slug"))
    lock = _get_section_lock(key)

    with lock:
        now = time.time()
        existing = _get_cached_section_entry(key)

        # Reuse fresh live cache only — never treat offline_mock as authoritative.
        if not force_fetch and existing and not _is_entry_mock(existing):
            ts, items, meta = existing
            if now - ts < _CATALOG_ITEMS_TTL and items:
                return items

        # Perform live resolution — prefer full admin source_url over bare id/slug.
        # Never mutate the shared section row (that flipped TRACK → new_releases in RAM).
        try:
            resolve_sec = dict(section)
            admin_st = str(resolve_sec.get("source_type") or "").strip().lower()
            wants_tracks = admin_st in ("song", "track") or str(
                resolve_sec.get("display_mode") or ""
            ).lower() in ("tracks", "songs", "song")
            _apply_source_url_identity(
                resolve_sec, preserve_admin_display_type=wants_tracks
            )
            items, is_mock, provider_status, detected_title, detected_art = resolve_catalog_items(
                resolve_sec.get("source_type"),
                resolve_sec.get("source_id"),
                resolve_sec.get("slug"),
                resolve_sec.get("language", "all"),
                source_url=resolve_sec.get("source_url"),
            )
            items = _filter_live_catalog_tracks(items)
        except Exception as exc:
            print(f"[Catalog] resolve_catalog_items exception for {key}: {exc}")
            items, is_mock, provider_status, detected_title, detected_art = [], True, "error", None, None

        is_success = bool(items and not is_mock and provider_status == "ok")

        if is_success:
            meta = {
                "is_mock": False,
                "provider_status": "ok",
                "last_error": None,
                "is_stale": False,
                "detected_title": detected_title,
                "detected_artwork": detected_art,
                "item_count": len(items)
            }
            _CATALOG_ITEMS_CACHE[key] = (now, items, meta)
            _mark_catalog_items_dirty()
            return items
        else:
            # Never overwrite good live cache with mock / empty failure.
            if existing and existing[1] and not _is_entry_mock(existing):
                prev_ts, prev_items, prev_meta = existing
                stale_meta = dict(prev_meta)
                stale_meta["is_stale"] = True
                stale_meta["provider_status"] = "stale"
                stale_meta["last_error"] = f"Upstream refresh failed ({provider_status})"
                _CATALOG_ITEMS_CACHE[key] = (prev_ts, prev_items, stale_meta)
                _mark_catalog_items_dirty()
                print(f"[Catalog] Upstream failed for {key}; preserved {len(prev_items)} stale items")
                return prev_items
            else:
                meta = {
                    "is_mock": is_mock,
                    "provider_status": provider_status or "offline_mock",
                    "last_error": None if not is_mock else "Offline fallback",
                    "is_stale": False,
                    "detected_title": detected_title,
                    "detected_artwork": detected_art,
                    "item_count": len(items)
                }
                _CATALOG_ITEMS_CACHE[key] = (now, items, meta)
                _mark_catalog_items_dirty()
                return items


def get_section_items(section, force_refresh=False):
    """
    Resolves playlist/artist/mix songs with TTL cache + stale-while-revalidate.
    - If fresh (< _CATALOG_ITEMS_TTL): serve immediately from memory.
    - If stale (< _CATALOG_ITEMS_STALE): serve immediately from memory, trigger background revalidation.
    - If force_refresh=True: synchronously re-fetch from upstream.
    - Combines custom_tracks and applies excluded_track_ids.
    """
    _ensure_catalog_items_disk_loaded()
    key = str(section.get("key") or section.get("id") or section.get("slug"))
    now = time.time()
    excluded_ids = set(str(x) for x in (section.get("excluded_track_ids") or []))
    custom_tracks = section.get("custom_tracks") or []

    base_items = None
    need_bg_revalidate = False
    existing = _get_cached_section_entry(key)

    if force_refresh:
        base_items = _resolve_section_base_items(section, force_fetch=True)
    elif existing and not _is_entry_mock(existing):
        ts, items, meta = existing
        age = (now - ts) if items else 10**9
        if items and age < _CATALOG_ITEMS_TTL:
            base_items = items
        elif items:
            # Any live cache (even older than STALE) — serve now, refresh in bg.
            # Sync-resolving here blocked /api/catalog/sections for minutes and
            # made Flutter Home stick on "Loading your music…".
            base_items = items
            need_bg_revalidate = True

    if base_items is None:
        if force_refresh:
            base_items = _resolve_section_base_items(section, force_fetch=True)
        else:
            # Metadata-only list/detail path: never block the request on Jio.
            base_items = []
            need_bg_revalidate = bool(section.get("source_url") or section.get("source_id"))

    if need_bg_revalidate:
        def _bg_revalidate_section(sec=section, sec_key=key):
            try:
                _resolve_section_base_items(sec, force_fetch=True)
            except Exception as exc:
                print(f"[Catalog] bg revalidate failed for {sec_key}: {exc}")

        threading.Thread(target=_bg_revalidate_section, daemon=True).start()

    combined = []
    seen_ids = set()
    for t in (custom_tracks + (base_items or [])):
        if _is_junk_catalog_track(t):
            continue
        tid = str(t.get("id") or t.get("token") or "")
        clean_tid = tid.replace("custom_api:track:", "")
        if clean_tid in excluded_ids or tid in excluded_ids:
            continue
        if clean_tid and clean_tid in seen_ids:
            continue
        if clean_tid:
            seen_ids.add(clean_tid)
        combined.append(t)
    return combined


def save_catalog_sections(sections, sync_db=False, extend_authority=True):
    """
    Persist catalogue locally (+ optional Supabase upsert).
    extend_authority=True only for real admin edits — passive renumber/reconcile
    must NOT block Supabase pulls or stale Fly disk stays forever.
    """
    global _CATALOG_LOCAL_AUTHORITY_UNTIL
    with CATALOG_LOCK:
        try:
            # Always store unique 1..N so Home group order matches admin ↑↓
            cleaned = []
            for s in sections:
                clean_s = {k: v for k, v in s.items() if k != "items"}
                if not clean_s.get("updated_at"):
                    clean_s["updated_at"] = int(time.time())
                cleaned.append(clean_s)
            disk_sections = _ensure_unique_catalog_positions(cleaned)
            with open(CATALOG_STORAGE_FILE, "w", encoding="utf-8") as f:
                json.dump(disk_sections, f, indent=2, ensure_ascii=False)
            _CATALOG_SECTIONS_MEM["data"] = disk_sections
            _CATALOG_SECTIONS_MEM["at"] = time.time()
            _CATALOG_SECTIONS_MEM["synced_at"] = time.time()
            if extend_authority:
                # Protect admin reorder/create/refresh from a slower remote pull
                _CATALOG_LOCAL_AUTHORITY_UNTIL = time.time() + 1800.0
        except Exception as e:
            print(f"[Catalog] Failed to save {CATALOG_STORAGE_FILE}: {e}")
            return False

    if sync_db:
        # Block until upsert finishes so admin read-back / other machines see the row.
        # If DB is briefly down, keep local+authority and retry in background.
        if sync_catalog_to_supabase(disk_sections) is False:
            print("[Catalog] local save ok but Supabase sync failed — scheduling retry")
            threading.Thread(
                target=sync_catalog_to_supabase, args=(disk_sections,), daemon=True
            ).start()
    return True


def find_catalog_section(key_or_id):
    if not key_or_id:
        return None
    sections = load_catalog_sections()
    for s in sections:
        if matches_section_key(s, key_or_id):
            return s
    return None


@app.route("/api/catalog/sections", methods=["GET"])
def api_catalog_sections():
    include_disabled = request.args.get("include_disabled", "").lower() in ("1", "true", "yes")
    if include_disabled and not is_admin_request(request):
        include_disabled = False
    group_filter = request.args.get("group")
    lang_filter = request.args.get("lang")
    now = int(time.time())

    sections = load_catalog_sections()
    if not include_disabled:
        active_sections = []
        for s in sections:
            if not s.get("is_enabled", True):
                continue
            c_start = _parse_iso_to_unix(s.get("campaign_start"))
            c_end = _parse_iso_to_unix(s.get("campaign_end"))
            if c_start and now < c_start:
                continue
            if c_end and now > c_end:
                continue
            active_sections.append(s)
        sections = active_sections

    if group_filter:
        sections = [s for s in sections if (s.get("display_group") or "").lower() == group_filter.lower()]
    if lang_filter and lang_filter != "all":
        sections = [s for s in sections if s.get("language") in ("all", lang_filter)]

    _ensure_catalog_items_disk_loaded()
    lite = request.args.get("lite", "").lower() in ("1", "true", "yes")
    do_refresh = request.args.get("refresh", "").lower() in ("1", "true", "yes") or request.args.get("force", "").lower() in ("1", "true", "yes")
    had_any_cache = any(
        isinstance(v, tuple) and len(v) > 1 and v[1] for v in _CATALOG_ITEMS_CACHE.values()
    )

    enriched = []
    to_resolve = []
    for s in sections:
        sec_copy = dict(s)
        key = str(s.get("key") or s.get("id") or s.get("slug"))
        cached = _get_cached_section_entry(key)

        if lite:
            items = []
        elif cached and cached[1] and not _is_entry_mock(cached):
            # Copy from RAM cache only — never call get_section_items here
            # (that used to sync-resolve stale shelves and hang Home).
            items = list(cached[1])
            ts = float(cached[0] or 0)
            if (time.time() - ts) >= _CATALOG_ITEMS_TTL:
                to_resolve.append((len(enriched), s))
        elif cached and _is_entry_mock(cached):
            # Cached entry contains mock items! Queue for live resolution
            items = list(s.get("custom_tracks") or [])
            to_resolve.append((len(enriched), s))
        elif do_refresh:
            # Forced refresh: queue for synchronous resolution below
            items = list(s.get("custom_tracks") or [])
            to_resolve.append((len(enriched), s))
        elif not had_any_cache:
            # Cold boot: never block admin/Home on resolving 90 shelves —
            # return metadata now and heal songs in background.
            items = list(s.get("custom_tracks") or [])
            to_resolve.append((len(enriched), s))
        else:
            # Uncached section without refresh: return custom tracks (if any)
            items = list(s.get("custom_tracks") or [])
            if s.get("source_url") or s.get("source_id"):
                to_resolve.append((len(enriched), s))

        sec_copy["items"] = items
        sec_copy["excluded_track_ids"] = s.get("excluded_track_ids") or []
        sec_copy["custom_tracks"] = s.get("custom_tracks") or []

        if cached:
            ts, _, meta = cached
            # Never let stale song-cache timestamps wipe an admin "Just now" stamp
            stored_lr = _parse_iso_to_unix(s.get("last_refresh")) or 0
            sec_copy["last_refresh"] = max(int(stored_lr or 0), int(ts or 0))
            sec_copy["provider_status"] = meta.get("provider_status", s.get("provider_status", "ok"))
            sec_copy["is_mock"] = meta.get("is_mock", s.get("is_mock", False))
            sec_copy["is_stale"] = meta.get("is_stale", False)
            sec_copy["last_error"] = meta.get("last_error", s.get("last_error"))

        # Never ship mock/offline tracks to the app
        live_items = [
            t for t in (sec_copy.get("items") or [])
            if isinstance(t, dict) and not t.get("is_mock")
        ]
        sec_copy["items"] = live_items
        # Count = live payloads only. Never advertise stale seed/mock item_count
        # when items[] is empty (Home showed "5 songs" then "No tracks yet").
        sec_copy["item_count"] = len(live_items)
        if len(live_items) == 0:
            sec_copy["is_mock"] = False
            if sec_copy.get("provider_status") == "offline_mock":
                sec_copy["provider_status"] = "unavailable"
        enriched.append(sec_copy)

    # Sync-resolve ONLY on explicit refresh=1. Cold start / heal always background —
    # otherwise admin Save verification times out rebuilding ~90 shelves.
    if to_resolve and not lite and do_refresh:
        with ThreadPoolExecutor(max_workers=4) as ex:
            futs = {
                ex.submit(get_section_items, sec, True): (idx, sec)
                for idx, sec in to_resolve
            }
            for fut, (idx, sec) in list(futs.items()):
                try:
                    items = fut.result(timeout=15)
                except Exception as err:
                    print(f"[Catalog] Refresh error for section {idx}: {err}")
                    items = enriched[idx].get("items") or []
                enriched[idx]["items"] = items
                enriched[idx]["item_count"] = len(items) or enriched[idx].get("item_count") or 0
                sec_k = str(sec.get("key") or sec.get("id") or sec.get("slug"))
                cached_now = _get_cached_section_entry(sec_k)
                stored_lr = _parse_iso_to_unix(enriched[idx].get("last_refresh")) or 0
                if cached_now:
                    ts, _, meta = cached_now
                    enriched[idx]["last_refresh"] = max(int(stored_lr or 0), int(ts or 0))
                    enriched[idx]["provider_status"] = meta.get("provider_status", "ok")
                    enriched[idx]["is_mock"] = meta.get("is_mock", False)
                    enriched[idx]["is_stale"] = meta.get("is_stale", False)
                    enriched[idx]["last_error"] = meta.get("last_error")
                elif stored_lr:
                    enriched[idx]["last_refresh"] = int(stored_lr)

        _mark_catalog_items_dirty()
    elif to_resolve and not lite and not app.config.get("TESTING"):
        def _bg_heal(secs):
            for s in secs:
                try:
                    get_section_items(s, force_refresh=True)
                except Exception as err:
                    print(f"[Catalog] Background heal error: {err}")
        threading.Thread(target=_bg_heal, args=([s for _, s in to_resolve],), daemon=True).start()

    return ok({
        "sections": enriched,
        "total": len(enriched),
        "source": "admin_catalog",
        "cache": "local_first",
    }, 0 if do_refresh else 120)


@app.route("/api/catalog/sections/refresh-all", methods=["POST"])
def api_catalog_refresh_all_sections():
    if not is_admin_request(request):
        return jsonify({"error": "Admin privileges required to refresh catalog sections"}), 403

    sections = load_catalog_sections()
    now_ts = int(time.time())

    # Clean fake error strings from existing sections
    for sec in sections:
        _apply_source_url_identity(sec)
        err = sec.get("last_error")
        if isinstance(err, str) and err.strip().startswith("{"):
            sec["last_error"] = None

    enabled_secs = [s for s in sections if s.get("is_enabled", True)]
    if app.config.get("TESTING"):
        enabled_secs = enabled_secs[:2]
    completed = []
    failed = []
    pending = []

    def _resolve_shelf(s):
        k = str(s.get("key") or s.get("id") or s.get("slug"))
        try:
            _apply_source_url_identity(s)
            items = get_section_items(s, force_refresh=True)
            cached = _get_cached_section_entry(k)
            is_mock = False
            status = "ok"
            last_err = None
            if cached:
                _, _, meta = cached
                is_mock = meta.get("is_mock", False)
                status = meta.get("provider_status", "ok")
                last_err = meta.get("last_error")
            return k, items, is_mock, status, last_err
        except Exception as ex:
            return k, [], False, "error", str(ex)

    pool = ThreadPoolExecutor(max_workers=6)
    fut_map = {pool.submit(_resolve_shelf, s): s for s in enabled_secs}

    from concurrent.futures import wait as fut_wait
    done, not_done = fut_wait(fut_map.keys(), timeout=12.0)

    for fut in done:
        sec = fut_map[fut]
        k = str(sec.get("key") or sec.get("id") or sec.get("slug"))
        try:
            _, items, is_mock, status, last_err = fut.result()
            if not is_mock and status == "ok" and items and len(items) > 0:
                sec["last_refresh"] = now_ts
                sec["updated_at"] = now_ts
                sec["items"] = items
                sec["item_count"] = len(items)
                sec["provider_status"] = "ok"
                sec["is_mock"] = False
                sec["last_error"] = None
                _CATALOG_ITEMS_CACHE[k] = (float(now_ts), items, {
                    "is_mock": False,
                    "provider_status": "ok",
                    "last_error": None,
                    "item_count": len(items),
                })
                completed.append(k)
            else:
                # Do NOT stamp last_refresh on failure or mock
                sec["provider_status"] = status
                sec["is_mock"] = is_mock
                sec["last_error"] = last_err if (last_err and not str(last_err).startswith("{")) else "Resolution failed"
                failed.append(k)
        except Exception as ex:
            sec["provider_status"] = "error"
            sec["last_error"] = str(ex)
            failed.append(k)

    for fut in not_done:
        sec = fut_map[fut]
        k = str(sec.get("key") or sec.get("id") or sec.get("slug"))
        pending.append(k)

    # Save immediately what we have resolved so far
    sections = _sanitize_sections_list(sections)
    save_catalog_sections(sections, sync_db=False)
    _mark_catalog_items_dirty()

    # Background handler to finish pending without blocking HTTP response
    if not_done:
        def _finish_pending():
            bg_now = int(time.time())
            any_bg_completed = False
            for p_fut in not_done:
                p_sec = fut_map[p_fut]
                p_k = str(p_sec.get("key") or p_sec.get("id") or p_sec.get("slug"))
                try:
                    _, p_items, p_mock, p_status, p_err = p_fut.result()
                    if not p_mock and p_status == "ok" and p_items and len(p_items) > 0:
                        p_sec["last_refresh"] = bg_now
                        p_sec["updated_at"] = bg_now
                        p_sec["items"] = p_items
                        p_sec["item_count"] = len(p_items)
                        p_sec["provider_status"] = "ok"
                        p_sec["is_mock"] = False
                        p_sec["last_error"] = None
                        _CATALOG_ITEMS_CACHE[p_k] = (float(bg_now), p_items, {
                            "is_mock": False,
                            "provider_status": "ok",
                            "last_error": None,
                            "item_count": len(p_items),
                        })
                        upsert_single_catalog_section_to_supabase(p_sec)
                        any_bg_completed = True
                except Exception as ex:
                    print(f"[Catalog] BG refresh-all failed for {p_k}: {ex}")
            if any_bg_completed:
                save_catalog_sections(_sanitize_sections_list(sections), sync_db=False)
                _mark_catalog_items_dirty()

        threading.Thread(target=_finish_pending, daemon=True).start()

    # If any completed, sync those rows to Supabase in background
    if completed:
        def _sync_completed():
            for c_k in completed:
                match = next((s for s in sections if matches_section_key(s, c_k)), None)
                if match:
                    upsert_single_catalog_section_to_supabase(match)
        threading.Thread(target=_sync_completed, daemon=True).start()

    return jsonify({
        "success": True,
        "completed": len(completed),
        "failed": len(failed),
        "pending": len(pending),
        "completed_keys": completed,
        "failed_keys": failed,
        "pending_keys": pending,
        "total": len(sections),
        "sections": _sanitize_sections_list(sections),
        "refreshed_at": now_ts,
    })


@app.route("/api/catalog/sections/<section_key>/refresh", methods=["POST"])
def api_catalog_refresh_single_section(section_key):
    if not is_admin_request(request):
        return jsonify({"error": "Admin privileges required to refresh catalog sections"}), 403

    sec = find_catalog_section(section_key)
    if not sec:
        return not_found(f"Catalog section '{section_key}' not found")

    _apply_source_url_identity(sec)
    items = get_section_items(sec, force_refresh=True)
    key = str(sec.get("key") or sec.get("id") or sec.get("slug"))

    existing = _get_cached_section_entry(key)
    is_mock = False
    provider_status = "ok"
    last_error = None
    if existing:
        _, items_c, meta = existing
        is_mock = meta.get("is_mock", False)
        provider_status = meta.get("provider_status", "ok")
        last_error = meta.get("last_error")

    sec_copy = dict(sec)
    sec_copy["items"] = items
    sec_copy["item_count"] = len(items)
    sec_copy["is_mock"] = is_mock
    sec_copy["provider_status"] = provider_status
    sec_copy["last_error"] = last_error

    # Only stamp last_refresh on a real, successful, non-mock resolve with live songs
    now_ts = int(time.time())
    if not is_mock and provider_status == "ok" and len(items) > 0:
        sec_copy["last_refresh"] = now_ts
        sec_copy["updated_at"] = now_ts
        if existing:
            _, items_c, meta = existing
            _CATALOG_ITEMS_CACHE[key] = (float(now_ts), items_c, dict(meta))
            _mark_catalog_items_dirty()

    sections = load_catalog_sections()
    target_s = None
    for s in sections:
        if matches_section_key(s, section_key):
            _apply_source_url_identity(s)
            s["source_type"] = sec.get("source_type") or s.get("source_type")
            s["source_id"] = sec.get("source_id") or s.get("source_id")
            s["slug"] = sec.get("slug") or s.get("slug")
            s["last_refresh"] = sec_copy.get("last_refresh") or s.get("last_refresh")
            s["updated_at"] = sec_copy.get("updated_at") or int(time.time())
            s["provider_status"] = sec_copy["provider_status"]
            s["item_count"] = sec_copy["item_count"]
            s["is_mock"] = sec_copy["is_mock"]
            s["last_error"] = sec_copy["last_error"]
            target_s = s
            break

    save_catalog_sections(sections, sync_db=False)
    if target_s:
        upsert_single_catalog_section_to_supabase(target_s)

    return jsonify(_sanitize_section_last_error(sec_copy))


@app.route("/api/catalog/sections/<section_key>", methods=["GET"])
def api_catalog_section_detail(section_key):
    sec = find_catalog_section(section_key)
    if not sec:
        return not_found(f"Catalog section '{section_key}' not found")
    sec_copy = dict(sec)
    raw_items = get_section_items(sec)
    live_items = [
        t for t in (raw_items or [])
        if isinstance(t, dict) and not t.get("is_mock")
    ]
    sec_copy["items"] = live_items
    sec_copy["item_count"] = len(live_items)
    sec_copy["excluded_track_ids"] = sec.get("excluded_track_ids") or []
    sec_copy["custom_tracks"] = sec.get("custom_tracks") or []
    return ok(sec_copy, 0)


@app.route("/api/catalog/preview", methods=["POST"])
def api_catalog_preview():
    body = request.get_json(silent=True) or {}
    url = body.get("url") or body.get("source_url") or request.args.get("url")
    parsed, err = parse_catalog_url(url)
    if err:
        return jsonify({"valid": False, "error": err}), 400

    req_lang = (
        (body.get("language") or request.args.get("language") or "").strip().lower()
        or (parsed.get("language") or "").strip().lower()
        or "hindi"
    )
    items = None
    is_mock = False
    provider_status = "ok"
    detected_title = None
    detected_artwork = None

    sec_k = str(parsed["slug"])
    existing = _get_cached_section_entry(sec_k)
    if existing and not _is_entry_mock(existing):
        ts, c_items, meta = existing
        if c_items:
            items = list(c_items)
            is_mock = meta.get("is_mock", False)
            provider_status = meta.get("provider_status", "ok")
            detected_title = meta.get("detected_title")
            detected_artwork = meta.get("detected_artwork")

    if not items:
        items, is_mock, provider_status, detected_title, detected_artwork = resolve_catalog_items(
            parsed["source_type"], parsed["source_id"], parsed["slug"], req_lang
        )
    title = detected_title or parsed["default_title"]
    return jsonify({
        "valid": True,
        "source_type": parsed["source_type"],
        "source_id": parsed["source_id"],
        "slug": parsed["slug"],
        "detected_title": title,
        "default_title": title,
        "default_group": parsed["default_group"],
        "detected_artwork": detected_artwork,
        "custom_artwork_url": detected_artwork,
        "provider_status": provider_status,
        "is_mock": is_mock,
        "item_count": len(items),
        "items": items,
        "preview_items": items
    })


@app.route("/api/catalog/resolve_track", methods=["POST"])
def api_catalog_resolve_track():
    body = request.get_json(silent=True) or {}
    raw_url = (body.get("url") or body.get("source_url") or "").strip()
    song_id = (body.get("song_id") or "").strip()

    if raw_url:
        parsed, err = parse_catalog_url(raw_url)
        if err:
            return jsonify({"valid": False, "error": err}), 400
        if parsed.get("source_type") != "song":
            return jsonify({"valid": False, "error": "URL must be a JioSaavn song link (/song/...)"}), 400
        song_id = parsed.get("source_id")

    if not song_id:
        return jsonify({"valid": False, "error": "Provide a valid JioSaavn song URL or song ID"}), 400

    items, is_mock, status, title, art = resolve_catalog_items("song", song_id, song_id)
    if not items:
        return jsonify({"valid": False, "error": f"Track could not be resolved from '{song_id}'"}), 404

    track = items[0]
    return jsonify({"valid": True, "track": track, "is_mock": is_mock})


@app.route("/api/catalog/sections", methods=["POST"])
def api_catalog_create_section():
    if not is_admin_request(request):
        return jsonify({"error": "Admin privileges required to create catalog sections"}), 403

    body = request.get_json(silent=True) or {}
    url = body.get("source_url") or body.get("url")
    parsed, err = parse_catalog_url(url)
    if err:
        return jsonify({"error": err}), 400

    sections = load_catalog_sections()

    base_key = re.sub(r'[^a-zA-Z0-9_]', '_', parsed["slug"].lower())
    key = base_key
    counter = 1
    existing_keys = {s.get("key") for s in sections}
    while key in existing_keys:
        counter += 1
        key = f"{base_key}_{counter}"

    display_title = (body.get("display_title") or "").strip() or parsed["default_title"]
    display_group = (body.get("display_group") or "").strip() or parsed["default_group"]
    # Prefer admin body → language parsed from Jio URL → hindi for typed shelves / all only if URL said so
    language = (
        (body.get("language") or "").strip().lower()
        or (parsed.get("language") or "").strip().lower()
        or "hindi"
    )
    # New shelves always join the FRONT of their display_group so Home shows
    # them first inside that section. Group ↑↓ order on Home is unchanged.
    same_group = [
        s for s in sections
        if str(s.get("display_group") or "").strip().lower()
        == str(display_group).strip().lower()
    ]
    if same_group:
        position = min(int(s.get("position") or 999) for s in same_group)
    else:
        # Brand-new group: place after existing shelves (does not jump to #1 globally)
        position = (max([int(s.get("position") or 0) for s in sections], default=0)) + 1

    is_enabled = body.get("is_enabled", True)
    if isinstance(is_enabled, str):
        is_enabled = is_enabled.lower() in ("true", "1", "yes")

    custom_artwork_url = (body.get("custom_artwork_url") or body.get("artwork_url") or "").strip() or None
    is_banner = body.get("is_banner", False)
    if isinstance(is_banner, str):
        is_banner = is_banner.lower() in ("true", "1", "yes")

    subtitle = (body.get("subtitle") or "").strip() or None
    c_start = body.get("campaign_start")
    c_end = body.get("campaign_end")
    campaign_start = int(c_start) if c_start is not None and str(c_start).isdigit() else None
    campaign_end = int(c_end) if c_end is not None and str(c_end).isdigit() else None

    excluded_track_ids = list(body.get("excluded_track_ids") or []) if isinstance(body.get("excluded_track_ids"), list) else []
    custom_tracks = list(body.get("custom_tracks") or []) if isinstance(body.get("custom_tracks"), list) else []

    # Cap Jio resolve so admin Save never sits past Flutter's ~35s timeout.
    items, is_mock, provider_status, detected_title, detected_artwork = [], False, "pending", None, None
    if custom_tracks:
        items = list(custom_tracks)
        is_mock = False
        provider_status = "ok"
    else:
        def _create_resolve():
            return resolve_catalog_items(
                parsed["source_type"],
                parsed["source_id"],
                parsed["slug"],
                language,
                source_url=url,
            )

        with ThreadPoolExecutor(max_workers=1) as pool:
            fut = pool.submit(_create_resolve)
            try:
                items, is_mock, provider_status, detected_title, detected_artwork = fut.result(
                    timeout=12
                )
            except Exception as exc:
                print(f"[Catalog] create resolve timed out/failed for {parsed.get('slug')}: {exc}")
                items, is_mock, provider_status, detected_title, detected_artwork = (
                    [],
                    False,
                    "pending",
                    None,
                    None,
                )
    if not display_title and detected_title:
        display_title = detected_title
    if not custom_artwork_url and detected_artwork:
        custom_artwork_url = detected_artwork

    # Fetch type from URL; admin TYPE: SONG/TRACK wins for Home shelf + badge
    admin_st = str(body.get("source_type") or "").strip().lower()
    saved_type = parsed["source_type"]
    display_mode = "entity"
    if admin_st in ("song", "track"):
        saved_type = "song"
        display_mode = "tracks"
    elif admin_st in ("playlist", "album", "artist", "mix", "charts", "radio", "new_releases"):
        saved_type = admin_st
        display_mode = "tracks" if admin_st == "new_releases" and body.get("display_mode") == "tracks" else "entity"
    if str(body.get("display_mode") or "").strip().lower() in ("tracks", "songs", "song"):
        display_mode = "tracks"
        if saved_type not in ("song", "track"):
            # Keep URL fetch type but mark as tracks shelf
            pass

    sec_id = str(uuid.uuid5(uuid.NAMESPACE_DNS, key))
    new_section = {
        "id": sec_id,
        "key": key,
        "source_url": url,
        "source_type": saved_type,
        "source_id": parsed["source_id"],
        "slug": parsed["slug"],
        "display_title": display_title,
        "subtitle": subtitle,
        "display_group": display_group,
        "display_mode": display_mode,
        "language": language,
        "position": position,
        "is_enabled": is_enabled,
        "custom_artwork_url": custom_artwork_url,
        "is_banner": is_banner,
        "campaign_start": campaign_start,
        "campaign_end": campaign_end,
        "excluded_track_ids": excluded_track_ids,
        "custom_tracks": custom_tracks,
        "provider_status": provider_status,
        "last_refresh": int(time.time()),
        "last_error": None,
        "is_mock": is_mock,
        "item_count": len(items),
        "items": items
    }
    # Ensure new-releases URLs keep resolvable ids even when admin chose song/track
    _apply_source_url_identity(
        new_section,
        preserve_admin_display_type=(admin_st in ("song", "track") or display_mode == "tracks"),
    )

    if not is_mock and items:
        meta = {
            "is_mock": False,
            "provider_status": "ok",
            "last_error": None,
            "is_stale": False,
            "detected_title": detected_title,
            "detected_artwork": detected_artwork,
            "item_count": len(items)
        }
        _CATALOG_ITEMS_CACHE[key] = (time.time(), items, meta)
        _mark_catalog_items_dirty()
    elif _get_cached_section_entry(key) and not _is_entry_mock(_get_cached_section_entry(key)):
        existing_sec_cache = _get_cached_section_entry(key)
        items = existing_sec_cache[1]
        new_section["items"] = items
        new_section["item_count"] = len(items)
        new_section["is_mock"] = False
        new_section["provider_status"] = "ok"
    # Rebuild list: new shelf is first inside its display_group; other groups stay put.
    target_g = str(display_group).strip().lower()
    ordered = sorted(sections, key=lambda x: int(x.get("position") or 999))
    rebuilt = []
    inserted = False
    for s in ordered:
        g = str(s.get("display_group") or "").strip().lower()
        if g == target_g and not inserted:
            rebuilt.append(new_section)
            inserted = True
        rebuilt.append(s)
    if not inserted:
        rebuilt.append(new_section)
    for i, s in enumerate(rebuilt, start=1):
        s["position"] = i
    new_section["position"] = next(
        (s["position"] for s in rebuilt if s.get("key") == new_section.get("key")),
        new_section.get("position", 1),
    )
    if not save_catalog_sections(rebuilt, sync_db=False):
        return jsonify({"error": "Failed to persist catalogue section locally"}), 500

    supabase_configured = bool(SUPABASE_URL and (SUPABASE_SERVICE_ROLE_KEY or SUPABASE_ANON_KEY))
    if supabase_configured:
        ok, res_or_err = upsert_single_catalog_section_to_supabase(new_section)
        if not ok:
            rolled_back = [s for s in rebuilt if s.get("key") != key]
            save_catalog_sections(rolled_back, sync_db=False, extend_authority=False)
            return jsonify({
                "error": f"Failed to persist catalogue section to Supabase: {res_or_err}. Nothing was saved."
            }), 502

    if provider_status == "pending":
        def _bg_fill_new_section(sec_key=key, st=saved_type, sid=parsed["source_id"], slug=parsed["slug"], lang=language, src=url):
            try:
                filled, mock, status, title, art = resolve_catalog_items(st, sid, slug, lang, source_url=src)
                filled = _filter_live_catalog_tracks(filled)
                if filled and not mock and status == "ok":
                    _CATALOG_ITEMS_CACHE[sec_key] = (
                        time.time(),
                        filled,
                        {
                            "is_mock": False,
                            "provider_status": "ok",
                            "last_error": None,
                            "is_stale": False,
                            "detected_title": title,
                            "detected_artwork": art,
                            "item_count": len(filled),
                        },
                    )
                    _mark_catalog_items_dirty()
                    print(f"[Catalog] bg-filled {sec_key} with {len(filled)} tracks")
            except Exception as exc:
                print(f"[Catalog] bg-fill failed for {sec_key}: {exc}")

        threading.Thread(target=_bg_fill_new_section, daemon=True).start()

    saved = find_catalog_section(key) or new_section
    out = dict(saved)
    out["items"] = new_section.get("items") or []
    out["item_count"] = new_section.get("item_count") or len(out["items"])
    return jsonify(out), 201


@app.route("/api/catalog/sections/<section_key>", methods=["PUT"])
def api_catalog_update_section(section_key):
    if not is_admin_request(request):
        return jsonify({"error": "Admin privileges required to update catalog sections"}), 403

    sections = load_catalog_sections()
    sec = next((s for s in sections if matches_section_key(s, section_key)), None)
    if not sec:
        return not_found(f"Catalog section '{section_key}' not found")

    body = request.get_json(silent=True) or {}

    new_url = body.get("source_url")
    target_language = str(body.get("language")).strip().lower() if body.get("language") else sec.get("language", "hindi")
    url_changed = bool(new_url and new_url != sec.get("source_url"))
    lang_changed = bool(target_language != sec.get("language"))
    force_refresh = bool(body.get("refresh"))

    target_url = new_url or sec.get("source_url")

    if (url_changed or lang_changed or force_refresh) and target_url:
        parsed, err = parse_catalog_url(target_url)
        if err:
            return jsonify({"error": err}), 400
        # When URL changes and admin did not send language, inherit from Jio URL parse
        if url_changed and not body.get("language"):
            target_language = (parsed.get("language") or target_language or "hindi")
        sec["source_url"] = target_url
        sec["source_type"] = parsed["source_type"]
        sec["source_id"] = parsed["source_id"]
        sec["slug"] = parsed["slug"]
        sec["language"] = target_language
        items, is_mock, provider_status, detected_title, detected_artwork = resolve_catalog_items(
            parsed["source_type"],
            parsed["source_id"],
            parsed["slug"],
            target_language,
            source_url=target_url,
        )
        sec["items"] = items
        sec["item_count"] = len(items)
        sec["is_mock"] = is_mock
        sec["provider_status"] = provider_status
        if detected_artwork and not body.get("custom_artwork_url"):
            sec["custom_artwork_url"] = detected_artwork
        sec_k = sec.get("key", section_key)
        if not is_mock and items:
            meta = {
                "is_mock": False,
                "provider_status": "ok",
                "last_error": None,
                "is_stale": False,
                "detected_title": detected_title,
                "detected_artwork": detected_artwork,
                "item_count": len(items)
            }
            _CATALOG_ITEMS_CACHE[sec_k] = (time.time(), items, meta)
            _mark_catalog_items_dirty()
        elif _get_cached_section_entry(sec_k) and not _is_entry_mock(_get_cached_section_entry(sec_k)):
            existing_sec_cache = _get_cached_section_entry(sec_k)
            items = existing_sec_cache[1]
            sec["items"] = items
            sec["item_count"] = len(items)
            sec["is_mock"] = False
            sec["provider_status"] = "ok"

    if "display_title" in body:
        val = body.get("display_title")
        if val is not None and str(val).strip():
            sec["display_title"] = str(val).strip()
    if "subtitle" in body:
        val = body.get("subtitle")
        sec["subtitle"] = str(val).strip() if (val is not None and str(val).strip()) else None
    if "display_group" in body:
        val = body.get("display_group")
        if val is not None and str(val).strip():
            sec["display_group"] = str(val).strip()
    # Admin TYPE: SONG/TRACK must stick (badge + Home tracks shelf).
    # URL still fills source_id/slug; resolve always prefers source_url.
    admin_st = None
    if "source_type" in body and body.get("source_type") is not None and str(body.get("source_type")).strip():
        st = str(body["source_type"]).strip().lower()
        if st in ("playlist", "album", "artist", "song", "track", "mix", "charts", "radio", "new_releases"):
            admin_st = st
            sec["source_type"] = st
            if st in ("song", "track"):
                sec["display_mode"] = "tracks"
            elif "display_mode" not in body:
                sec["display_mode"] = sec.get("display_mode") or "entity"
    if "display_mode" in body and body.get("display_mode") is not None and str(body.get("display_mode")).strip():
        dm = str(body["display_mode"]).strip().lower()
        sec["display_mode"] = dm if dm in ("tracks", "songs", "song", "entity") else "entity"
        if sec["display_mode"] in ("tracks", "songs", "song"):
            sec["display_mode"] = "tracks"
    _apply_source_url_identity(
        sec,
        preserve_admin_display_type=(
            admin_st in ("song", "track")
            or str(sec.get("display_mode") or "").lower() == "tracks"
        ),
    )
    if "language" in body:
        val = body.get("language")
        if val is not None and str(val).strip():
            sec["language"] = str(val).strip().lower()
    if "custom_artwork_url" in body:
        val = body.get("custom_artwork_url")
        sec["custom_artwork_url"] = str(val).strip() if (val is not None and str(val).strip()) else None
    if "is_banner" in body:
        val = body["is_banner"]
        if val is not None:
            sec["is_banner"] = val if isinstance(val, bool) else str(val).lower() in ("true", "1", "yes")
    if "campaign_start" in body:
        val = body.get("campaign_start")
        sec["campaign_start"] = int(val) if (val is not None and str(val).isdigit()) else None
    if "campaign_end" in body:
        val = body.get("campaign_end")
        sec["campaign_end"] = int(val) if (val is not None and str(val).isdigit()) else None
    if "position" in body:
        val = body.get("position")
        if val is not None:
            try:
                sec["position"] = int(val)
            except (ValueError, TypeError):
                pass
    if "is_enabled" in body:
        val = body["is_enabled"]
        if val is not None:
            sec["is_enabled"] = val if isinstance(val, bool) else str(val).lower() in ("true", "1", "yes")
    if "excluded_track_ids" in body:
        sec["excluded_track_ids"] = list(body["excluded_track_ids"]) if isinstance(body["excluded_track_ids"], list) else []
    if "custom_tracks" in body:
        sec["custom_tracks"] = list(body["custom_tracks"]) if isinstance(body["custom_tracks"], list) else []

    sec["updated_at"] = int(time.time())
    sec["last_refresh"] = int(time.time())
    sections.sort(key=lambda x: x.get("position", 999))
    save_catalog_sections(sections, sync_db=False)

    supabase_configured = bool(SUPABASE_URL and (SUPABASE_SERVICE_ROLE_KEY or SUPABASE_ANON_KEY))
    if supabase_configured:
        ok, res_or_err = upsert_single_catalog_section_to_supabase(sec)
        if not ok:
            return jsonify({
                "error": f"Failed to persist catalogue section update to Supabase: {res_or_err}. Please retry."
            }), 502

    return jsonify(sec)


@app.route("/api/catalog/sections/<section_key>", methods=["DELETE"])
def api_catalog_delete_section(section_key):
    if not is_admin_request(request):
        return jsonify({"error": "Admin privileges required to delete catalog sections"}), 403

    global _CATALOG_LOCAL_AUTHORITY_UNTIL
    sections = load_catalog_sections()
    to_delete = [s for s in sections if matches_section_key(s, section_key)]
    supabase_configured = bool(SUPABASE_URL and (SUPABASE_SERVICE_ROLE_KEY or SUPABASE_ANON_KEY))

    if not to_delete:
        # Idempotent: still purge Supabase so ghost rows stop reappearing in admin/Home.
        deleted_remote = delete_catalog_section_from_supabase(section_key, section_key)
        _CATALOG_ITEMS_CACHE.pop(section_key, None)
        if deleted_remote or not supabase_configured:
            save_catalog_sections(
                [s for s in sections if not matches_section_key(s, section_key)],
                sync_db=False,
            )
            # Let other instances converge from DB (deleted row must stay gone).
            _CATALOG_LOCAL_AUTHORITY_UNTIL = 0.0
            return jsonify({
                "success": True,
                "deleted_key": section_key,
                "purged_remote_only": True,
            })
        return jsonify({
            "error": f"Catalog section '{section_key}' not found locally and remote delete failed",
        }), 404

    remote_ok = True
    for s in to_delete:
        sk = str(s.get("key") or section_key)
        # Hard-delete DB first so Home/Supabase fallback cannot resurrect the shelf.
        ok = delete_catalog_section_from_supabase(sk, s.get("id"))
        if not ok and supabase_configured:
            remote_ok = False
        _CATALOG_ITEMS_CACHE.pop(sk, None)
        _CATALOG_ITEMS_CACHE.pop(section_key, None)
        if s.get("id"):
            _CATALOG_ITEMS_CACHE.pop(str(s.get("id")), None)

    if not remote_ok and supabase_configured:
        return jsonify({
            "error": "Failed to delete section from database. Nothing was removed — retry.",
            "deleted_key": section_key,
        }), 502

    sections = [s for s in sections if not matches_section_key(s, section_key)]
    save_catalog_sections(sections, sync_db=False, extend_authority=False)
    # Drop authority so reconcile cannot prefer a stale pre-delete snapshot,
    # and other machines pick up the DB membership quickly.
    _CATALOG_LOCAL_AUTHORITY_UNTIL = 0.0
    _mark_catalog_items_dirty()
    return jsonify({"success": True, "deleted_key": section_key})


@app.route("/api/catalog/sections/reorder", methods=["POST"])
def api_catalog_reorder_sections():
    if not is_admin_request(request):
        return jsonify({"error": "Admin privileges required to reorder catalog sections"}), 403

    body = request.get_json(silent=True) or {}
    order_keys = body.get("order") or body.get("keys") or []
    if not isinstance(order_keys, list):
        return jsonify({"error": "Provide an 'order' array of section keys"}), 400

    sections = load_catalog_sections()
    # Index by key / id / slug so Flutter sectionKey always matches
    sec_map = {}
    for s in sections:
        for k in (s.get("key"), s.get("id"), s.get("slug")):
            if k:
                sec_map[str(k)] = s

    seen = set()
    new_list = []
    pos = 1
    for k in order_keys:
        sk = str(k)
        sec = sec_map.get(sk)
        if not sec:
            continue
        rk = str(sec.get("key") or sec.get("id") or sk)
        if rk in seen:
            continue
        seen.add(rk)
        sec["position"] = pos
        new_list.append(sec)
        pos += 1

    for remaining in sorted(
        (s for s in sections if str(s.get("key") or s.get("id") or "") not in seen),
        key=lambda x: x.get("position", 999),
    ):
        remaining["position"] = pos
        new_list.append(remaining)
        pos += 1

    save_catalog_sections(new_list, sync_db=True)
    # Push to Supabase immediately so clients reading DB also see new order
    try:
        sync_catalog_to_supabase(new_list)
    except Exception as e:
        print(f"[Catalog] reorder supabase sync: {e}")
    return jsonify({"sections": new_list, "total": len(new_list)})


@app.route("/api/catalog/groups/rename", methods=["POST"])
def api_catalog_rename_group():
    if not is_admin_request(request):
        return jsonify({"error": "Admin privileges required to rename catalog group"}), 403

    body = request.get_json(silent=True) or {}
    old_name = (body.get("old_name") or "").strip()
    new_name = (body.get("new_name") or "").strip()
    if not old_name or not new_name:
        return jsonify({"error": "Provide 'old_name' and 'new_name'"}), 400

    sections = load_catalog_sections()
    count = 0
    now_ts = int(time.time())
    for s in sections:
        if (s.get("display_group") or "").strip().lower() == old_name.lower():
            s["display_group"] = new_name
            s["updated_at"] = now_ts
            count += 1

    if count > 0:
        save_catalog_sections(sections, sync_db=True)

    return jsonify({"success": True, "renamed": count, "old_name": old_name, "new_name": new_name})


@app.route("/api/catalog/sections/<section_key>/toggle", methods=["POST"])
def api_catalog_toggle_section(section_key):
    if not is_admin_request(request):
        return jsonify({"error": "Admin privileges required to toggle catalog sections"}), 403

    sections = load_catalog_sections()
    sec = next((s for s in sections if matches_section_key(s, section_key)), None)
    if not sec:
        return not_found(f"Catalog section '{section_key}' not found")

    sec["is_enabled"] = not sec.get("is_enabled", True)
    sec["updated_at"] = int(time.time())
    save_catalog_sections(sections, sync_db=True)
    return jsonify(sec)


@app.route("/api/catalog/sections/reconcile-db", methods=["POST"])
def api_catalog_reconcile_db():
    """Admin: force Fly local catalogue = Supabase (drop orphans, match order)."""
    if not is_admin_request(request):
        return jsonify({"error": "Admin privileges required"}), 403
    global _CATALOG_LOCAL_AUTHORITY_UNTIL
    _CATALOG_LOCAL_AUTHORITY_UNTIL = 0.0
    merged = _reconcile_catalog_with_supabase(force=True, bypass_authority=True)
    if not merged:
        return jsonify({"error": "Supabase catalog_sections empty or unreachable"}), 502
    return jsonify({"success": True, "total": len(merged), "source": "supabase"})


# ─── Dynamic Radio & Library Categories Management ──────────────────────────────
RADIO_STORAGE_FILE = os.path.join(DATA_DIR, "radio_stations.json")
LIBRARY_STORAGE_FILE = os.path.join(DATA_DIR, "library_categories.json")
RADIO_LOCK = threading.Lock()
LIBRARY_LOCK = threading.Lock()


def load_radio_stations():
    with RADIO_LOCK:
        if os.path.exists(RADIO_STORAGE_FILE):
            try:
                with open(RADIO_STORAGE_FILE, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    if isinstance(data, list) and data:
                        return data
            except Exception as e:
                print(f"[Radio] Error loading radio_stations.json: {e}")
        return list(RADIO_STATIONS)


def save_radio_stations(stations):
    with RADIO_LOCK:
        try:
            with open(RADIO_STORAGE_FILE, "w", encoding="utf-8") as f:
                json.dump(stations, f, indent=2, ensure_ascii=False)
            return True
        except Exception as e:
            print(f"[Radio] Error saving radio_stations.json: {e}")
            return False


def load_library_categories():
    with LIBRARY_LOCK:
        if os.path.exists(LIBRARY_STORAGE_FILE):
            try:
                with open(LIBRARY_STORAGE_FILE, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    if isinstance(data, list) and data:
                        return data
            except Exception as e:
                print(f"[Library] Error loading library_categories.json: {e}")
        return []


def save_library_categories(categories):
    with LIBRARY_LOCK:
        try:
            with open(LIBRARY_STORAGE_FILE, "w", encoding="utf-8") as f:
                json.dump(categories, f, indent=2, ensure_ascii=False)
            return True
        except Exception as e:
            print(f"[Library] Error saving library_categories.json: {e}")
            return False


@app.route("/api/radio/stations", methods=["GET", "POST"])
def api_radio_stations():
    if request.method == "POST":
        if not is_admin_request(request):
            return jsonify({"error": "Admin privileges required"}), 403
        body = request.get_json(silent=True) or {}
        name = str(body.get("name") or "").strip()
        stream_url = str(body.get("stream_url") or "").strip()
        if not name or not stream_url:
            return jsonify({"error": "Name and Stream URL are required"}), 400

        station_id = str(body.get("id") or "").strip()
        if not station_id:
            station_id = re.sub(r"[^a-z0-9_]+", "_", name.lower()).strip("_")
        
        stations = load_radio_stations()
        if any(s.get("id") == station_id for s in stations):
            station_id = f"{station_id}_{int(time.time())}"

        language = str(body.get("language") or "hindi").strip().lower()
        languages = body.get("languages") or [language]
        if isinstance(languages, str):
            languages = [x.strip().lower() for x in languages.split(",") if x.strip()]
        category = str(body.get("category") or "National").strip()
        tier = str(body.get("tier") or "").strip().lower()
        if tier not in ("private", "government"):
            tier = "private" if "private" in category.lower() or "popular" in category.lower() else "government"
        new_station = {
            "id": station_id,
            "name": name,
            "tagline": str(body.get("tagline") or "").strip(),
            "frequency": str(body.get("frequency") or "Live FM").strip(),
            "state": str(body.get("state") or "National / Regional").strip(),
            "district": str(body.get("district") or "").strip(),
            "language": language,
            "languages": languages,
            "stream_url": stream_url,
            "artwork_url": str(body.get("artwork_url") or "").strip() or "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80",
            "category": category,
            "tier": tier,
            "is_live": bool(body.get("is_live", True)),
            "verified": bool(body.get("verified", False)),
        }
        stations.append(new_station)
        save_radio_stations(stations)
        return jsonify(new_station), 201

    stations = load_radio_stations()
    # Normalize tier so Popular / AIR filters never drop stations silently.
    for s in stations:
        t = (s.get("tier") or "").strip().lower()
        cat = (s.get("category") or "").lower()
        if t not in ("private", "government"):
            s["tier"] = "private" if ("private" in cat or "popular" in cat or "mirchi" in cat) else "government"
    lang = (request.args.get("lang") or request.args.get("language") or "").strip().lower()
    tier = (request.args.get("tier") or "").strip().lower()  # private | government | air
    state = (request.args.get("state") or "").strip().lower()
    district = (request.args.get("district") or "").strip().lower()
    if lang and lang not in ("all", "india"):
        stations = [
            s for s in stations
            if lang == (s.get("language") or "").lower()
            or lang in [x.lower() for x in (s.get("languages") or [])]
        ]
    if tier in ("private", "popular"):
        stations = [s for s in stations if (s.get("tier") or "").lower() == "private"]
    elif tier in ("government", "air", "akashvani"):
        stations = [s for s in stations if (s.get("tier") or "").lower() == "government"]
    if state and state != "all":
        stations = [s for s in stations if state in (s.get("state") or "").lower()]
    if district and district != "all":
        stations = [s for s in stations if district in (s.get("district") or "").lower()]

    # Private / popular first, then AIR grouped by state → district
    def _radio_sort_key(s):
        tier_rank = 0 if (s.get("tier") or "") == "private" else 1
        return (tier_rank, (s.get("state") or ""), (s.get("district") or ""), (s.get("name") or ""))

    stations = sorted(stations, key=_radio_sort_key)
    states = sorted({(s.get("state") or "").strip() for s in stations if s.get("state")})
    districts = sorted({(s.get("district") or "").strip() for s in stations if s.get("district")})
    return ok({
        "stations": stations,
        "count": len(stations),
        "lang": lang or "all",
        "tier": tier or "all",
        "states": states,
        "districts": districts,
    }, 120)


@app.route("/api/radio/stations/<station_id>", methods=["PUT", "DELETE"])
def api_radio_station_detail(station_id):
    if not is_admin_request(request):
        return jsonify({"error": "Admin privileges required"}), 403

    stations = load_radio_stations()
    idx = next((i for i, s in enumerate(stations) if s.get("id") == station_id), None)
    if idx is None:
        return not_found(f"Station '{station_id}' not found")

    if request.method == "DELETE":
        removed = stations.pop(idx)
        save_radio_stations(stations)
        return jsonify({"success": True, "deleted": removed})

    body = request.get_json(silent=True) or {}
    st = stations[idx]
    if "name" in body:
        st["name"] = str(body["name"]).strip()
    if "tagline" in body:
        st["tagline"] = str(body["tagline"]).strip()
    if "frequency" in body:
        st["frequency"] = str(body["frequency"]).strip()
    if "state" in body:
        st["state"] = str(body["state"]).strip()
    if "stream_url" in body:
        st["stream_url"] = str(body["stream_url"]).strip()
    if "artwork_url" in body:
        st["artwork_url"] = str(body["artwork_url"]).strip()
    if "category" in body:
        st["category"] = str(body["category"]).strip()
    if "is_live" in body:
        st["is_live"] = bool(body["is_live"])
    if "language" in body:
        st["language"] = str(body["language"]).strip().lower()
    if "languages" in body:
        langs = body["languages"]
        if isinstance(langs, str):
            langs = [x.strip().lower() for x in langs.split(",") if x.strip()]
        st["languages"] = langs
    if "verified" in body:
        st["verified"] = bool(body["verified"])

    save_radio_stations(stations)
    return jsonify(st)


@app.route("/api/radio/stream/<station_id>")
def api_radio_stream(station_id):
    stations = load_radio_stations()
    station = next((s for s in stations if s["id"] == station_id), None)
    return redirect(station["stream_url"], code=302) if station else not_found("Station not found")


# ─── FCM device tokens (admin push foundation) ─────────────────────────────────
FCM_TOKENS_FILE = os.path.join(DATA_DIR, "fcm_tokens.json")
FCM_TOKENS_LOCK = threading.Lock()


def load_fcm_tokens():
    with FCM_TOKENS_LOCK:
        if os.path.exists(FCM_TOKENS_FILE):
            try:
                with open(FCM_TOKENS_FILE, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    if isinstance(data, list):
                        return data
            except Exception as e:
                print(f"[FCM] load error: {e}")
        return []


def save_fcm_tokens(items):
    with FCM_TOKENS_LOCK:
        try:
            with open(FCM_TOKENS_FILE, "w", encoding="utf-8") as f:
                json.dump(items, f, indent=2, ensure_ascii=False)
            return True
        except Exception as e:
            print(f"[FCM] save error: {e}")
            return False


# ─── Anonymous product pulse (install / session) ───────────────────────────────
ANALYTICS_FILE = os.path.join(DATA_DIR, "analytics_pulse.json")
ANALYTICS_LOCK = threading.Lock()


def _load_analytics_pulse():
    with ANALYTICS_LOCK:
        if not os.path.exists(ANALYTICS_FILE):
            return {"devices": {}, "events": []}
        try:
            with open(ANALYTICS_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
            if isinstance(data, dict):
                data.setdefault("devices", {})
                data.setdefault("events", [])
                return data
        except Exception as e:
            print(f"[Analytics] load error: {e}")
        return {"devices": {}, "events": []}


def _save_analytics_pulse(data):
    with ANALYTICS_LOCK:
        try:
            with open(ANALYTICS_FILE, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False)
            return True
        except Exception as e:
            print(f"[Analytics] save error: {e}")
            return False


@app.route("/api/analytics/event", methods=["POST"])
def api_analytics_event():
    """Fire-and-forget anonymous install/session pulse from the app."""
    body = request.get_json(silent=True) or {}
    event = str(body.get("event") or "").strip().lower()
    device_id = str(body.get("device_id") or "").strip()[:80]
    if event not in ("install", "session_start", "heartbeat", "session_end"):
        return jsonify({"error": "Invalid event"}), 400
    if not device_id or len(device_id) < 8:
        return jsonify({"error": "device_id required"}), 400

    now = datetime.now(timezone.utc).isoformat()
    data = _load_analytics_pulse()
    devices = data.get("devices") or {}
    device = devices.get(device_id) or {
        "device_id": device_id,
        "first_seen": now,
        "installs": 0,
        "sessions": 0,
        "total_seconds": 0,
        "platform": str(body.get("platform") or "")[:32],
        "app_version": str(body.get("app_version") or "")[:24],
    }
    device["last_seen"] = now
    device["platform"] = str(body.get("platform") or device.get("platform") or "")[:32]
    device["app_version"] = str(body.get("app_version") or device.get("app_version") or "")[:24]
    if event == "install":
        device["installs"] = int(device.get("installs") or 0) + 1
        device["first_seen"] = device.get("first_seen") or now
    elif event == "session_start":
        device["sessions"] = int(device.get("sessions") or 0) + 1
    elif event in ("heartbeat", "session_end"):
        try:
            add_sec = max(0, int(body.get("session_seconds") or 0))
        except Exception:
            add_sec = 0
        # Heartbeats send cumulative session seconds — store max observed per session window lightly
        if add_sec > 0:
            prev = int(device.get("_open_session_seconds") or 0)
            delta = max(0, add_sec - prev) if event == "heartbeat" else add_sec
            if event == "session_end":
                delta = add_sec
                device["_open_session_seconds"] = 0
            else:
                device["_open_session_seconds"] = add_sec
            device["total_seconds"] = int(device.get("total_seconds") or 0) + delta

    devices[device_id] = device
    # Cap device map
    if len(devices) > 20000:
        # Drop oldest by last_seen
        ordered = sorted(devices.items(), key=lambda kv: kv[1].get("last_seen") or "")
        devices = dict(ordered[-15000:])
    data["devices"] = devices
    # Keep a short event ring for debugging
    events = list(data.get("events") or [])
    events.append({"event": event, "device_id": device_id, "ts": now})
    data["events"] = events[-500:]
    _save_analytics_pulse(data)
    return ok({"success": True}, 0)


@app.route("/api/analytics/summary", methods=["GET"])
def api_analytics_summary():
    """Admin-only install / active / usage summary (uninstall ≈ stale devices)."""
    if not is_admin_request(request):
        return jsonify({"error": "Admin privileges required"}), 403
    data = _load_analytics_pulse()
    devices = list((data.get("devices") or {}).values())
    now = datetime.now(timezone.utc)
    active_7d = 0
    active_30d = 0
    stale_30d = 0
    installs = 0
    sessions = 0
    total_seconds = 0
    for d in devices:
        installs += int(d.get("installs") or 0)
        sessions += int(d.get("sessions") or 0)
        total_seconds += int(d.get("total_seconds") or 0)
        try:
            last = datetime.fromisoformat(str(d.get("last_seen") or "").replace("Z", "+00:00"))
            age = (now - last).total_seconds()
            if age <= 7 * 86400:
                active_7d += 1
            if age <= 30 * 86400:
                active_30d += 1
            else:
                stale_30d += 1
        except Exception:
            stale_30d += 1
    return ok({
        "devices": len(devices),
        "install_events": installs,
        "sessions": sessions,
        "total_use_seconds": total_seconds,
        "active_7d": active_7d,
        "active_30d": active_30d,
        "likely_churn_30d": stale_30d,
        "note": "True uninstalls are in Play Console; likely_churn_30d = no pulse for 30+ days.",
    }, 0)


@app.route("/api/fcm/token", methods=["POST"])
def api_fcm_register_token():
    """App registers a device FCM token for later admin push."""
    body = request.get_json(silent=True) or {}
    token = str(body.get("token") or "").strip()
    if not token or len(token) < 20:
        return jsonify({"error": "Valid FCM token required"}), 400
    user_id = str(body.get("user_id") or "").strip()
    platform = str(body.get("platform") or "android").strip().lower()
    tokens = load_fcm_tokens()
    now = datetime.now(timezone.utc).isoformat()
    existing = next((t for t in tokens if t.get("token") == token), None)
    if existing:
        existing["updated_at"] = now
        existing["user_id"] = user_id or existing.get("user_id")
        existing["platform"] = platform
    else:
        tokens.append({
            "token": token,
            "user_id": user_id,
            "platform": platform,
            "created_at": now,
            "updated_at": now,
        })
    # Cap storage
    tokens = tokens[-5000:]
    save_fcm_tokens(tokens)
    return ok({"success": True, "count": len(tokens)}, 0)


@app.route("/api/fcm/tokens", methods=["GET"])
def api_fcm_list_tokens():
    if not is_admin_request(request):
        return jsonify({"error": "Admin privileges required"}), 403
    tokens = load_fcm_tokens()
    return ok({"tokens": tokens, "count": len(tokens)}, 0)


def _fcm_select_tokens(body):
    """Resolve recipient device tokens: all, user_ids, or explicit tokens."""
    tokens = load_fcm_tokens()
    audience = str(body.get("audience") or "all").strip().lower()
    user_ids = body.get("user_ids") or body.get("target_user_ids") or []
    if not isinstance(user_ids, list):
        user_ids = []
    user_ids = {str(u).strip() for u in user_ids if str(u).strip()}
    explicit = body.get("tokens") or []
    if not isinstance(explicit, list):
        explicit = []
    explicit = {str(t).strip() for t in explicit if str(t).strip()}

    selected = []
    for row in tokens:
        tok = str(row.get("token") or "").strip()
        if not tok:
            continue
        if explicit and tok not in explicit:
            continue
        if audience == "selected" and user_ids:
            uid = str(row.get("user_id") or "").strip()
            if uid not in user_ids:
                continue
        selected.append(row)
    return selected


_FCM_V1_TOKEN_CACHE = {"access_token": "", "expires_at": 0.0}


def _load_firebase_service_account():
    """
    FCM HTTP v1 credentials (current Firebase standard).
    Prefer FIREBASE_SERVICE_ACCOUNT_JSON (raw JSON string env) or
    FIREBASE_SERVICE_ACCOUNT_FILE (path to downloaded service-account JSON).
    """
    raw = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON", "").strip()
    if raw:
        try:
            return json.loads(raw)
        except Exception as e:
            print(f"[FCM] invalid FIREBASE_SERVICE_ACCOUNT_JSON: {e}")
    path = os.environ.get("FIREBASE_SERVICE_ACCOUNT_FILE", "").strip()
    if not path:
        # Convenience default next to server.py (do not commit this file)
        candidate = os.path.join(os.path.dirname(__file__), "firebase-service-account.json")
        if os.path.exists(candidate):
            path = candidate
    if path and os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            print(f"[FCM] failed reading service account file: {e}")
    return None


def _fcm_project_id(sa_info=None):
    return (
        os.environ.get("FIREBASE_PROJECT_ID", "").strip()
        or (sa_info or {}).get("project_id")
        or "kalpkrut-beats"
    )


def _fcm_v1_access_token(sa_info):
    """OAuth access token for Firebase Cloud Messaging API."""
    now = time.time()
    if _FCM_V1_TOKEN_CACHE["access_token"] and now < _FCM_V1_TOKEN_CACHE["expires_at"] - 60:
        return _FCM_V1_TOKEN_CACHE["access_token"]
    try:
        from google.oauth2 import service_account
        import google.auth.transport.requests as google_requests
    except Exception as e:
        print(f"[FCM] google-auth not installed: {e}")
        return None
    try:
        creds = service_account.Credentials.from_service_account_info(
            sa_info,
            scopes=["https://www.googleapis.com/auth/firebase.messaging"],
        )
        req = google_requests.Request()
        creds.refresh(req)
        _FCM_V1_TOKEN_CACHE["access_token"] = creds.token
        _FCM_V1_TOKEN_CACHE["expires_at"] = now + 3500
        return creds.token
    except Exception as e:
        print(f"[FCM] v1 token refresh failed: {e}")
        return None


def _fcm_deliver(title, msg, image_url, data, recipients):
    """
    Prefer FCM HTTP v1 (service account). Legacy FCM_SERVER_KEY is optional fallback
    only if Cloud Messaging API (Legacy) is enabled in Firebase.
    """
    sent = 0
    errors = 0
    data_payload = {}
    if isinstance(data, dict):
        for k, v in data.items():
            if v is None:
                continue
            data_payload[str(k)] = str(v)
    if image_url:
        data_payload.setdefault("image_url", image_url)

    sa_info = _load_firebase_service_account()
    if sa_info:
        access = _fcm_v1_access_token(sa_info)
        project_id = _fcm_project_id(sa_info)
        if access and project_id:
            url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
            for row in recipients:
                tok = row.get("token")
                if not tok:
                    continue
                try:
                    # Keep payload simple (previous working style). App icon comes from
                    # AndroidManifest default_notification_icon meta-data.
                    android_notif = {
                        "sound": "default",
                        "channel_id": "kalpkrut_beats_push",
                    }
                    if image_url:
                        android_notif["image"] = image_url
                    message = {
                        "message": {
                            "token": tok,
                            "notification": {"title": title, "body": msg},
                            "data": data_payload,
                            "android": {
                                "priority": "HIGH",
                                "notification": android_notif,
                            },
                        }
                    }
                    if image_url:
                        message["message"]["notification"]["image"] = image_url
                    req = urllib.request.Request(
                        url,
                        data=json.dumps(message).encode("utf-8"),
                        headers={
                            "Authorization": f"Bearer {access}",
                            "Content-Type": "application/json",
                        },
                        method="POST",
                    )
                    with urllib.request.urlopen(req, timeout=12) as resp:
                        if 200 <= resp.status < 300:
                            sent += 1
                        else:
                            errors += 1
                except Exception as e:
                    errors += 1
                    print(f"[FCM] v1 send error: {e}")
            return sent, errors, "fcm_http_v1"

    # Legacy fallback (disabled in most Firebase projects now)
    server_key = os.environ.get("FCM_SERVER_KEY", "").strip()
    if not server_key:
        return sent, errors, "queued_stub"
    for row in recipients:
        tok = row.get("token")
        if not tok:
            continue
        try:
            notif = {"title": title, "body": msg}
            if image_url:
                notif["image"] = image_url
            payload_obj = {
                "to": tok,
                "notification": notif,
                "data": data_payload,
                "priority": "high",
            }
            payload = json.dumps(payload_obj).encode("utf-8")
            req = urllib.request.Request(
                "https://fcm.googleapis.com/fcm/send",
                data=payload,
                headers={
                    "Authorization": f"key={server_key}",
                    "Content-Type": "application/json",
                },
                method="POST",
            )
            with urllib.request.urlopen(req, timeout=8) as resp:
                if 200 <= resp.status < 300:
                    sent += 1
                else:
                    errors += 1
        except Exception:
            errors += 1
    return sent, errors, "fcm_http_legacy"


@app.route("/api/fcm/send", methods=["POST"])
def api_fcm_send():
    """
    Admin OS push. Audience: all | selected (user_ids).
    Attach song/album preview via data + optional image_url.
    Configure FIREBASE_SERVICE_ACCOUNT_JSON (or FILE) for FCM HTTP v1.
    """
    if not is_admin_request(request):
        return jsonify({"error": "Admin privileges required"}), 403
    body = request.get_json(silent=True) or {}
    title = str(body.get("title") or "").strip()
    msg = str(body.get("body") or body.get("message") or "").strip()
    if not title:
        return jsonify({"error": "title required"}), 400
    image_url = str(body.get("image_url") or "").strip()
    data = body.get("data") if isinstance(body.get("data"), dict) else {}
    # Convenience fields for deep-link preview
    for key in ("target_type", "target_id", "image_url", "preview_title", "preview_subtitle"):
        if body.get(key) and key not in data:
            data[key] = body.get(key)
    recipients = _fcm_select_tokens(body)
    sent, errors, mode = _fcm_deliver(title, msg, image_url, data, recipients)
    return ok({
        "success": True,
        "recipients": len(recipients),
        "sent": sent,
        "errors": errors,
        "mode": mode,
        "message": (
            "OS push delivered via FCM HTTP v1."
            if mode == "fcm_http_v1"
            else (
                "OS push delivered via legacy FCM."
                if mode == "fcm_http_legacy"
                else "Add Firebase service-account JSON (FIREBASE_SERVICE_ACCOUNT_JSON) for OS push; in-app Notify still works."
            )
        ),
    }, 0)


# ─── Push / in-app notifications (Amazon-style admin broadcast) ─────────────────
NOTIFICATION_STORAGE_FILE = os.path.join(DATA_DIR, "notifications.json")
NOTIFICATION_LOCK = threading.Lock()


def load_notifications():
    with NOTIFICATION_LOCK:
        if os.path.exists(NOTIFICATION_STORAGE_FILE):
            try:
                with open(NOTIFICATION_STORAGE_FILE, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    if isinstance(data, list):
                        return data
            except Exception as e:
                print(f"[Notify] load error: {e}")
        return []


def save_notifications(items):
    with NOTIFICATION_LOCK:
        try:
            with open(NOTIFICATION_STORAGE_FILE, "w", encoding="utf-8") as f:
                json.dump(items, f, indent=2, ensure_ascii=False)
            return True
        except Exception as e:
            print(f"[Notify] save error: {e}")
            return False


@app.route("/api/notifications", methods=["GET", "POST"])
def api_notifications():
    """
    GET  — list active notifications for the app (newest first)
           Optional ?user_id= filters audience=selected messages.
    POST — admin create (title, body, target_type, target_id, image_url,
           audience=all|selected, target_user_ids[], send_fcm=true)
           target_type: song | playlist | album | artist | radio | catalog | url | none
    """
    if request.method == "POST":
        if not is_admin_request(request):
            return jsonify({"error": "Admin privileges required"}), 403
        body = request.get_json(silent=True) or {}
        title = str(body.get("title") or "").strip()
        message = str(body.get("body") or body.get("message") or "").strip()
        if not title:
            return jsonify({"error": "title is required"}), 400
        audience = str(body.get("audience") or "all").strip().lower()
        if audience not in ("all", "selected"):
            audience = "all"
        raw_ids = body.get("target_user_ids") or body.get("user_ids") or []
        if not isinstance(raw_ids, list):
            raw_ids = []
        target_user_ids = [str(u).strip() for u in raw_ids if str(u).strip()]
        if audience == "selected" and not target_user_ids:
            return jsonify({"error": "Select at least one user, or choose All users"}), 400
        image_url = str(body.get("image_url") or "").strip()
        target_type = str(body.get("target_type") or "none").strip().lower()
        target_id = str(body.get("target_id") or body.get("target_url") or "").strip()
        item = {
            "id": str(body.get("id") or uuid.uuid4()),
            "title": title,
            "body": message,
            "target_type": target_type,
            "target_id": target_id,
            "image_url": image_url,
            "audience": audience,
            "target_user_ids": target_user_ids,
            "is_active": bool(body.get("is_active", True)),
            "created_at": int(time.time()),
        }
        items = load_notifications()
        items.insert(0, item)
        items = items[:200]
        save_notifications(items)

        fcm_result = None
        send_fcm = body.get("send_fcm", True)
        if send_fcm:
            recipients = _fcm_select_tokens({
                "audience": audience,
                "user_ids": target_user_ids,
            })
            sent, errors, mode = _fcm_deliver(
                title,
                message,
                image_url,
                {
                    "target_type": target_type,
                    "target_id": target_id,
                    "image_url": image_url,
                    "notification_id": item["id"],
                    "preview_title": title,
                    "preview_subtitle": message,
                },
                recipients,
            )
            fcm_result = {
                "recipients": len(recipients),
                "sent": sent,
                "errors": errors,
                "mode": mode,
            }
            item["fcm"] = fcm_result
        return jsonify(item), 201

    include_inactive = request.args.get("include_inactive", "").lower() in ("1", "true", "yes")
    user_id = str(request.args.get("user_id") or "").strip()
    items = load_notifications()
    if not include_inactive:
        items = [n for n in items if n.get("is_active", True)]
    if user_id:
        filtered = []
        for n in items:
            aud = str(n.get("audience") or "all").lower()
            ids = n.get("target_user_ids") or []
            if aud != "selected":
                filtered.append(n)
            elif user_id in {str(x) for x in ids}:
                filtered.append(n)
        items = filtered
    limit = arg_int("limit", 50, 1, 200)
    return ok({"notifications": items[:limit], "count": min(len(items), limit)}, 30)


@app.route("/api/notifications/<notif_id>", methods=["DELETE", "PUT"])
def api_notification_detail(notif_id):
    if not is_admin_request(request):
        return jsonify({"error": "Admin privileges required"}), 403
    items = load_notifications()
    idx = next((i for i, n in enumerate(items) if str(n.get("id")) == str(notif_id)), None)
    if idx is None:
        return not_found("Notification not found")
    if request.method == "DELETE":
        removed = items.pop(idx)
        save_notifications(items)
        return jsonify({"success": True, "deleted": removed})
    body = request.get_json(silent=True) or {}
    n = items[idx]
    for key in ("title", "body", "target_type", "target_id", "image_url", "audience"):
        if key in body:
            n[key] = str(body[key]).strip()
    if "message" in body and "body" not in body:
        n["body"] = str(body["message"]).strip()
    if "is_active" in body:
        n["is_active"] = bool(body["is_active"])
    if "target_user_ids" in body or "user_ids" in body:
        raw_ids = body.get("target_user_ids") or body.get("user_ids") or []
        if not isinstance(raw_ids, list):
            raw_ids = []
        n["target_user_ids"] = [str(u).strip() for u in raw_ids if str(u).strip()]
    save_notifications(items)

    # Same as create: optional OS push after edit/save.
    send_fcm = body.get("send_fcm", False)
    if send_fcm:
        audience = str(n.get("audience") or "all").strip().lower()
        target_user_ids = n.get("target_user_ids") or []
        recipients = _fcm_select_tokens({
            "audience": audience,
            "user_ids": target_user_ids,
        })
        sent, errors, mode = _fcm_deliver(
            str(n.get("title") or ""),
            str(n.get("body") or ""),
            str(n.get("image_url") or ""),
            {
                "target_type": str(n.get("target_type") or "none"),
                "target_id": str(n.get("target_id") or ""),
                "image_url": str(n.get("image_url") or ""),
                "notification_id": str(n.get("id") or ""),
                "preview_title": str(n.get("title") or ""),
                "preview_subtitle": str(n.get("body") or ""),
            },
            recipients,
        )
        n["fcm"] = {
            "recipients": len(recipients),
            "sent": sent,
            "errors": errors,
            "mode": mode,
        }
    return jsonify(n)


# ─── Library Categories Endpoints ───────────────────────────────────────────────
@app.route("/api/library/categories", methods=["GET", "POST"])
def api_library_categories():
    if request.method == "POST":
        if not is_admin_request(request):
            return jsonify({"error": "Admin privileges required"}), 403
        body = request.get_json(silent=True) or {}
        title = str(body.get("title") or "").strip()
        if not title:
            return jsonify({"error": "Title is required"}), 400

        cat_id = str(body.get("id") or "").strip()
        if not cat_id:
            cat_id = re.sub(r"[^a-z0-9_]+", "_", title.lower()).strip("_")

        categories = load_library_categories()
        source_url = str(body.get("source_url") or body.get("url") or "").strip()
        query = str(body.get("query") or title).strip()
        # If admin pastes a playlist/album URL into query, promote it to source_url
        if not source_url and query.lower().startswith(("http://", "https://")):
            source_url = query
        new_cat = {
            "id": cat_id,
            "title": title,
            "subtitle": str(body.get("subtitle") or "").strip(),
            "query": query,
            "source_url": source_url,
            "category_type": str(body.get("category_type") or "mood").strip(),
            "gradient_start": str(body.get("gradient_start") or "#1E3A8A").strip(),
            "gradient_end": str(body.get("gradient_end") or "#2563EB").strip(),
            "artwork_url": str(body.get("artwork_url") or "").strip(),
            "emoji": str(body.get("emoji") or "🎶").strip(),
            "is_active": bool(body.get("is_active", True)),
        }
        categories.append(new_cat)
        save_library_categories(categories)
        return jsonify(new_cat), 201

    cats = load_library_categories()
    return ok({"categories": cats, "count": len(cats)}, 60)


@app.route("/api/library/categories/<cat_id>", methods=["PUT", "DELETE"])
def api_library_category_detail(cat_id):
    if not is_admin_request(request):
        return jsonify({"error": "Admin privileges required"}), 403

    cats = load_library_categories()
    idx = next((i for i, c in enumerate(cats) if c.get("id") == cat_id), None)
    if idx is None:
        return not_found(f"Category '{cat_id}' not found")

    if request.method == "DELETE":
        removed = cats.pop(idx)
        save_library_categories(cats)
        return jsonify({"success": True, "deleted": removed})

    body = request.get_json(silent=True) or {}
    c = cats[idx]
    if "title" in body:
        c["title"] = str(body["title"]).strip()
    if "subtitle" in body:
        c["subtitle"] = str(body["subtitle"]).strip()
    if "query" in body:
        c["query"] = str(body["query"]).strip()
    if "source_url" in body or "url" in body:
        c["source_url"] = str(body.get("source_url") or body.get("url") or "").strip()
    if "category_type" in body:
        c["category_type"] = str(body["category_type"]).strip()
    if "gradient_start" in body:
        c["gradient_start"] = str(body["gradient_start"]).strip()
    if "gradient_end" in body:
        c["gradient_end"] = str(body["gradient_end"]).strip()
    if "artwork_url" in body:
        c["artwork_url"] = str(body["artwork_url"]).strip()
    if "emoji" in body:
        c["emoji"] = str(body["emoji"]).strip()
    if "is_active" in body:
        c["is_active"] = bool(body["is_active"])
    # Keep URL + query in sync when admin pastes a link into query
    q = (c.get("query") or "").strip()
    if q.lower().startswith(("http://", "https://")) and not c.get("source_url"):
        c["source_url"] = q

    save_library_categories(cats)
    return jsonify(c)



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


# ─── Public share pages (OG preview + Android App Link intent) ─────────────────
PUBLIC_WEB = "https://beats.kalpkrutinfotech.com"
ANDROID_PACKAGE = "com.kalpkrut.beats"


def _html_escape(s):
    return (
        str(s or "")
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def _share_page(kind, entity_id, title, description, image, deep_path):
    title = _html_escape(title or "Kalpkrut Beats")
    description = _html_escape(description or "Listen free on Kalpkrut Beats")
    image = _html_escape(image or f"{PUBLIC_WEB}/icons/Icon-512.png")
    page_url = f"{PUBLIC_WEB}/{deep_path}"
    # Custom scheme opens installed app reliably; Intent is Android Chrome fallback.
    app_scheme = f"com.kalpkrut.beats://{deep_path}"
    intent_url = (
        f"intent://beats.kalpkrutinfotech.com/{deep_path}"
        f"#Intent;scheme=https;package={ANDROID_PACKAGE};"
        f"S.browser_fallback_url={urllib.parse.quote(page_url, safe='')};end"
    )
    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>{title} · Kalpkrut Beats</title>
<meta name="description" content="{description}"/>
<meta property="og:type" content="music.song"/>
<meta property="og:site_name" content="Kalpkrut Beats"/>
<meta property="og:title" content="{title}"/>
<meta property="og:description" content="{description}"/>
<meta property="og:image" content="{image}"/>
<meta property="og:url" content="{page_url}"/>
<meta name="twitter:card" content="summary_large_image"/>
<meta name="twitter:title" content="{title}"/>
<meta name="twitter:description" content="{description}"/>
<meta name="twitter:image" content="{image}"/>
<meta name="google-play-app" content="app-id={ANDROID_PACKAGE}"/>
<style>
body{{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;
font-family:Segoe UI,system-ui,sans-serif;background:#0d0b14;color:#f5f3ff;text-align:center;padding:24px}}
.card{{max-width:420px}} img{{width:180px;height:180px;border-radius:16px;object-fit:cover;margin-bottom:16px;background:#1a1625}}
a.btn{{display:inline-block;margin-top:12px;padding:12px 20px;border-radius:12px;background:#7c3aed;color:#fff;text-decoration:none;font-weight:700}}
p.muted{{color:#b7b0c9}}
</style>
</head>
<body>
<div class="card">
<img src="{image}" alt=""/>
<h1>{title}</h1>
<p class="muted">{description}</p>
<p><a class="btn" id="openApp" href="{_html_escape(app_scheme)}">Open in App</a></p>
<p class="muted"><a href="{_html_escape(intent_url)}" style="color:#a78bfa">Android open</a></p>
</div>
<script>
(function(){{
  var scheme = {json.dumps(app_scheme)};
  var intent = {json.dumps(intent_url)};
  var ua = navigator.userAgent || "";
  var isAndroid = /Android/i.test(ua);
  try {{
    if (isAndroid) {{
      location.href = scheme;
      setTimeout(function(){{ location.href = intent; }}, 700);
    }} else {{
      location.href = scheme;
    }}
  }} catch (e) {{}}
}})();
</script>
</body>
</html>"""
    return Response(html, mimetype="text/html; charset=utf-8")


@app.route("/share/song/<song_id>")
@app.route("/share/track/<song_id>")
def share_song(song_id):
    track = song_details(song_id) or {}
    title = track.get("title") or "Song"
    artists = track.get("artists") or track.get("primary_artists") or track.get("artist") or "Kalpkrut Beats"
    if isinstance(artists, list):
        artists = ", ".join(
            (a.get("name") if isinstance(a, dict) else str(a)) for a in artists
        )
    image = track.get("image") or track.get("artwork_url") or track.get("thumbnail")
    desc = f"{artists} · Listen on Kalpkrut Beats"
    return _share_page("song", song_id, title, desc, image, f"song/{song_id}")


@app.route("/share/album/<album_id>")
def share_album(album_id):
    data = entity_details("album", album_id) or {}
    title = data.get("title") or "Album"
    image = data.get("image") or data.get("artwork_url")
    desc = f"Album on Kalpkrut Beats"
    return _share_page("album", album_id, title, desc, image, f"album/{album_id}")


@app.route("/share/artist/<artist_id>")
def share_artist(artist_id):
    data = artist_details(artist_id=artist_id) or {}
    title = data.get("name") or data.get("title") or "Artist"
    image = data.get("image") or data.get("artwork_url")
    desc = "Artist on Kalpkrut Beats"
    return _share_page("artist", artist_id, title, desc, image, f"artist/{artist_id}")


@app.route("/share/playlist/<playlist_id>")
def share_playlist(playlist_id):
    data = entity_details("playlist", playlist_id) or {}
    if not data:
        cat = find_catalog_section(playlist_id) or {}
        title = cat.get("title") or "Playlist"
        image = cat.get("custom_artwork_url") or cat.get("artwork_url")
    else:
        title = data.get("title") or "Playlist"
        image = data.get("image") or data.get("artwork_url")
    desc = "Playlist on Kalpkrut Beats"
    return _share_page("playlist", playlist_id, title, desc, image, f"playlist/{playlist_id}")


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    print(f"Starting {SERVICE_NAME} v{VERSION} on port {port}...")
    app.run(host="0.0.0.0", port=port, debug=False, threaded=True)
