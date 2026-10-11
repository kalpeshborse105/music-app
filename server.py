"""
Kalpkrut Beats — Music Streaming API & Gateway Server
Production-grade Flask backend with resilient DES decryption, smart deduplication,
hourly JioSaavn trending & playlist refresh, related song auto-queue, and 24/7 radio streaming.
"""

import os
import re
import sys
import time
import html
import json
import base64
import urllib.request
import urllib.parse
import threading

# ─── Optional Flask & CORS Support ───────────────────────────────────────────
try:
    from flask import Flask, request, jsonify, redirect, Response, send_from_directory, render_template
    from flask_cors import CORS
    FLASK_AVAILABLE = True
except ImportError:
    FLASK_AVAILABLE = False

# ─── Optional PyCryptodome with Guaranteed Pure Python DES Fallback ──────────
try:
    from Crypto.Cipher import DES as PyCryptoDES
    PYCRYPTO_AVAILABLE = True
except ImportError:
    PYCRYPTO_AVAILABLE = False

# ─── Pure Python DES Implementation (Zero External Dependencies) ─────────────
_IP = [
    58, 50, 42, 34, 26, 18, 10, 2, 60, 52, 44, 36, 28, 20, 12, 4,
    62, 54, 46, 38, 30, 22, 14, 6, 64, 56, 48, 40, 32, 24, 16, 8,
    57, 49, 41, 33, 25, 17, 9, 1, 59, 51, 43, 35, 27, 19, 11, 3,
    61, 53, 45, 37, 29, 21, 13, 5, 63, 55, 47, 39, 31, 23, 15, 7,
]
_FP = [
    40, 8, 48, 16, 56, 24, 64, 32, 39, 7, 47, 15, 55, 23, 63, 31,
    38, 6, 46, 14, 54, 22, 62, 30, 37, 5, 45, 13, 53, 21, 61, 29,
    36, 4, 44, 12, 52, 20, 60, 28, 35, 3, 43, 11, 51, 19, 59, 27,
    34, 2, 42, 10, 50, 18, 58, 26, 33, 1, 41, 9, 49, 17, 57, 25,
]
_PC1 = [
    57, 49, 41, 33, 25, 17, 9, 1, 58, 50, 42, 34, 26, 18,
    10, 2, 59, 51, 43, 35, 27, 19, 11, 3, 60, 52, 44, 36,
    63, 55, 47, 39, 31, 23, 15, 7, 62, 54, 46, 38, 30, 22,
    14, 6, 61, 53, 45, 37, 29, 21, 13, 5, 28, 20, 12, 4,
]
_PC2 = [
    14, 17, 11, 24, 1, 5, 3, 28, 15, 6, 21, 10,
    23, 19, 12, 4, 26, 8, 16, 7, 27, 20, 13, 2,
    41, 52, 31, 37, 47, 55, 30, 40, 51, 45, 33, 48,
    44, 49, 39, 56, 34, 53, 46, 42, 50, 36, 29, 32,
]
_SHIFTS = [1, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1]
_E = [
    32, 1, 2, 3, 4, 5, 4, 5, 6, 7, 8, 9,
    8, 9, 10, 11, 12, 13, 12, 13, 14, 15, 16, 17,
    16, 17, 18, 19, 20, 21, 20, 21, 22, 23, 24, 25,
    24, 25, 26, 27, 28, 29, 28, 29, 30, 31, 32, 1,
]
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
_P = [
    16, 7, 20, 21, 29, 12, 28, 17, 1, 15, 23, 26, 5, 18, 31, 10,
    2, 8, 24, 14, 32, 27, 3, 9, 19, 13, 30, 6, 22, 11, 4, 25,
]

def _permute(bits, table):
    return [bits[i - 1] for i in table]

def _bytes_to_bits(b):
    res = []
    for byte in b:
        for i in range(7, -1, -1):
            res.append((byte >> i) & 1)
    return res

def _bits_to_bytes(bits):
    res = bytearray()
    for i in range(0, len(bits), 8):
        byte = 0
        for b in bits[i : i + 8]:
            byte = (byte << 1) | b
        res.append(byte)
    return bytes(res)

def _generate_subkeys(key_bytes):
    key_bits = _bytes_to_bits(key_bytes)
    c = _permute(key_bits, _PC1[:28])
    d = _permute(key_bits, _PC1[28:])
    subkeys = []
    for shift in _SHIFTS:
        c = c[shift:] + c[:shift]
        d = d[shift:] + d[:shift]
        subkeys.append(_permute(c + d, _PC2))
    return subkeys

def _des_block(block_bits, subkeys):
    bits = _permute(block_bits, _IP)
    l, r = bits[:32], bits[32:]
    for k in subkeys:
        er = _permute(r, _E)
        xored = [er[i] ^ k[i] for i in range(48)]
        s_out = []
        for i in range(8):
            chunk = xored[i * 6 : (i + 1) * 6]
            row = (chunk[0] << 1) | chunk[5]
            col = (chunk[1] << 3) | (chunk[2] << 2) | (chunk[3] << 1) | chunk[4]
            val = _S_BOX[i][row][col]
            for bit in range(3, -1, -1):
                s_out.append((val >> bit) & 1)
        f_out = _permute(s_out, _P)
        l, r = r, [l[i] ^ f_out[i] for i in range(32)]
    return _permute(r + l, _FP)

def _pure_des_decrypt(key_bytes, cipher_bytes):
    subkeys = _generate_subkeys(key_bytes)[::-1]
    plaintext = bytearray()
    for i in range(0, len(cipher_bytes), 8):
        blk = cipher_bytes[i : i + 8]
        if len(blk) < 8:
            break
        blk_bits = _bytes_to_bits(blk)
        dec_bits = _des_block(blk_bits, subkeys)
        plaintext.extend(_bits_to_bytes(dec_bits))
    return bytes(plaintext)

def decrypt_media_url(encrypted_url: str) -> str:
    """Decrypts JioSaavn encrypted media URLs using PyCryptodome or Pure-Python DES."""
    if not encrypted_url:
        return ""
    try:
        key = b"38346591"
        enc = encrypted_url.replace("_", "/").replace("-", "+")
        enc += "=" * (-len(enc) % 4)
        enc_bytes = base64.b64decode(enc)

        if PYCRYPTO_AVAILABLE:
            cipher = PyCryptoDES.new(key, PyCryptoDES.MODE_ECB)
            dec = cipher.decrypt(enc_bytes)
        else:
            dec = _pure_des_decrypt(key, enc_bytes)

        dec = dec.rstrip(b"\x00\x01\x02\x03\x04\x05\x06\x07\x08\t\n\x0b\x0c\r\x0e\x0f\x10")
        url = dec.decode("utf-8", errors="ignore").strip()
        url = url.replace("http:", "https:")
        url = re.sub(r"_96\.mp4", "_320.mp4", url)
        url = re.sub(r"_160\.mp4", "_320.mp4", url)
        return url
    except Exception as e:
        print(f"[DES Decrypt Error] {e}")
        return ""


# ─── Caches & Deduplication Engine ───────────────────────────────────────────
_STREAM_CACHE = {}     # {track_id: stream_url}
_TRACK_CACHE = {}      # {track_id: track_dict}
_HOURLY_CACHE = {}     # {cache_key: (timestamp, data)}
CACHE_TTL_SECONDS = 3600  # 1 Hour TTL for fresh daily/hourly song updates

def normalize_title(title: str) -> str:
    """Normalizes title to eliminate duplicate uploads/remixes."""
    if not title:
        return ""
    t = title.lower()
    t = re.sub(r"\(.*?\)", "", t)
    t = re.sub(r"\[.*?\]", "", t)
    t = re.sub(r"\b(remix|lofi|lo-fi|acoustic|version|feat|ft|official|audio|video)\b", "", t)
    t = re.sub(r"[^\w\s]", "", t)
    return " ".join(t.split())

def deduplicate_tracks(tracks: list, exclude_titles: set = None, exclude_ids: set = None) -> list:
    """Removes duplicate tracks by id and normalized song title."""
    seen_ids = set(exclude_ids or [])
    seen_titles = set(exclude_titles or [])
    unique = []

    for t in tracks:
        tid = t.get("id")
        norm = normalize_title(t.get("title", ""))
        if not tid or tid in seen_ids:
            continue
        if norm and norm in seen_titles:
            continue

        seen_ids.add(tid)
        if norm:
            seen_titles.add(norm)
        unique.append(t)

    return unique


# ─── JioSaavn Network Client ──────────────────────────────────────────────────
_JIO_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "application/json, text/plain, */*",
    "Referer": "https://www.jiosaavn.com/",
}

def _jio_get(url: str, timeout: int = 12) -> dict:
    req = urllib.request.Request(url, headers=_JIO_HEADERS)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        raw = resp.read().decode("utf-8", errors="ignore").strip()
        # JioSaavn sometimes wraps with JSONP or nulls
        if raw.startswith("/**/"):
            raw = raw[4:].strip()
        if raw.endswith(";"):
            raw = raw[:-1].strip()
        return json.loads(raw)


def _format_track(item: dict) -> dict:
    """Converts a raw JioSaavn item into standard Kalpkrut Beats track format."""
    if not item or not isinstance(item, dict):
        return {}
    tid = str(item.get("id") or "")
    more = item.get("more_info", {})
    enc = more.get("encrypted_media_url", "") or item.get("encrypted_media_url", "")
    stream_url = decrypt_media_url(enc) if enc else (item.get("media_preview_url") or "")

    if stream_url and tid:
        _STREAM_CACHE[tid] = stream_url

    title = html.unescape(item.get("title", "") or item.get("song", "") or "Unknown Title")
    artist = html.unescape(item.get("subtitle", "") or more.get("music", "") or item.get("primary_artists", "") or "Unknown Artist")
    album = html.unescape(more.get("album", "") or item.get("album", "") or "Single")
    img = (item.get("image") or "").replace("150x150", "500x500").replace("http:", "https:")

    try:
        dur_sec = int(more.get("duration", 0) or item.get("duration", 0) or 0)
    except Exception:
        dur_sec = 0

    track = {
        "id": tid,
        "title": title,
        "artist": artist,
        "album": album,
        "artwork_url": img,
        "thumbnail": img,
        "duration_ms": dur_sec * 1000,
        "duration": dur_sec,
        "stream_url": stream_url or f"/api/play/{tid}",
        "download_url": stream_url,
        "source": "jiosaavn",
    }
    if tid:
        _TRACK_CACHE[tid] = track
    return track


def _jio_search(query: str, limit: int = 20, page: int = 1, dedup: bool = True) -> list:
    """Searches JioSaavn songs with full 320kbps resolution and deduplication."""
    try:
        url = (
            f"https://www.jiosaavn.com/api.php?__call=search.getResults"
            f"&_format=json&_marker=0&api_version=4&ctx=wap6dot0"
            f"&q={urllib.parse.quote(query)}&p={page}&n={limit}"
        )
        data = _jio_get(url)
        results = data.get("results", [])
        raw = [_format_track(r) for r in results if r]
        return deduplicate_tracks(raw) if dedup else raw
    except Exception as e:
        print(f"[_jio_search error] {e}")
        return []


def _jio_get_song_by_id(song_id: str) -> dict:
    """Fetches song details by id, decrypting 320kbps media stream."""
    if not song_id:
        return {}
    if song_id in _TRACK_CACHE:
        return _TRACK_CACHE[song_id]
    try:
        url = (
            f"https://www.jiosaavn.com/api.php?__call=song.getDetails"
            f"&cc=in&_marker=0&_format=json&pids={urllib.parse.quote(song_id)}"
        )
        data = _jio_get(url)
        item = data.get(song_id) or (list(data.values())[0] if data else None)
        return _format_track(item)
    except Exception as e:
        print(f"[_jio_get_song_by_id error] {e}")
        return {}


def _jio_get_related(song_id: str, title: str, artist: str, limit: int = 15) -> list:
    """
    Fetches real-time related song suggestions based on current song,
    strictly EXCLUDING the current song to prevent repeating the same song.
    """
    related = []
    current_norm = normalize_title(title)
    exclude_ids = {song_id} if song_id else set()
    exclude_titles = {current_norm} if current_norm else set()

    # 1. Try JioSaavn official recommendation API (reco.getreco)
    if song_id:
        try:
            url = (
                f"https://www.jiosaavn.com/api.php?__call=reco.getreco"
                f"&_format=json&_marker=0&api_version=4&ctx=wap6dot0&pid={urllib.parse.quote(song_id)}"
            )
            data = _jio_get(url)
            if isinstance(data, list):
                for item in data:
                    t = _format_track(item)
                    if t and t.get("id"):
                        related.append(t)
        except Exception:
            pass

    # 2. If recommendations are fewer than requested, query artist & genre catalog
    if len(related) < limit:
        primary_artist = artist.split(",")[0].split("&")[0].strip() if artist else ""
        query = primary_artist or title or "Latest Bollywood Hits"
        search_candidates = _jio_search(query, limit=limit + 5, dedup=True)
        related.extend(search_candidates)

    # 3. Deduplicate and ensure CURRENT SONG IS NEVER REPEATED
    filtered = deduplicate_tracks(related, exclude_titles=exclude_titles, exclude_ids=exclude_ids)
    return filtered[:limit]


# ─── Hourly Updated Language & Mood Catalog ──────────────────────────────────
LANGUAGE_QUERIES = {
    "all": [
        "Latest Bollywood Hits", "Trending Hindi Songs", "Top Bollywood Songs",
        "Arijit Singh Hits", "Punjabi Top Hits", "Romantic Hindi Hits",
        "Bollywood Dance Mashup", "Indian Pop Hits", "New Hindi Releases",
    ],
    "hindi": [
        "Latest Bollywood Hits", "Trending Hindi Songs", "Arijit Singh Best",
        "Romantic Hindi Songs", "Hindi Retro Classics", "90s Hindi Hits",
    ],
    "punjabi": [
        "Latest Punjabi Hits", "Trending Punjabi Songs", "Sidhu Moosewala Hits",
        "Diljit Dosanjh Hits", "Karan Aujla Top Songs",
    ],
    "bhojpuri": [
        "Top Bhojpuri Hits", "Pawan Singh Hits", "Khesari Lal Yadav Songs",
    ],
    "marathi": [
        "Top Marathi Hits", "Ajay Atul Hits", "Latest Marathi Songs",
    ],
    "gujarati": [
        "Top Gujarati Hits", "Kinjal Dave Hits", "Geeta Rabari Songs",
    ],
    "south": [
        "Top Tamil Hits", "Top Telugu Hits", "Anirudh Ravichander Hits", "SS Thaman Hits",
    ],
    "devotional": [
        "Shree Hanuman Chalisa", "Top Bhakti Songs", "Shiv Bhajan Hits", "Krishna Bhakti Songs",
    ],
    "classics": [
        "Lata Mangeshkar Golden Hits", "Kishore Kumar Classics", "Mohammad Rafi Hits",
    ],
}


# ─── Verified 24/7 Live Radio Stations ───────────────────────────────────────
RADIO_STATIONS = [
    {
        "id": "air_vividh_bharati",
        "name": "AIR Vividh Bharati",
        "category": "Golden Era / Retro Classics",
        "stream_url": "https://air.pc.cdn.bitgravity.com/air/live/pbaudio001/playlist.m3u8",
        "description": "Immortal Bollywood classics & golden era memories from Akashvani Mumbai.",
        "bitrate": "192 kbps HD",
        "is_live": True,
    },
    {
        "id": "air_fm_gold",
        "name": "AIR FM Gold Delhi",
        "category": "Retro Melodies & News",
        "stream_url": "https://airhlspush.pc.cdn.bitgravity.com/httppush/hlspbaudio005/hlspbaudio00564kbps.m3u8",
        "description": "National broadcast of timeless retro songs and midday melodies.",
        "bitrate": "192 kbps HD",
        "is_live": True,
    },
    {
        "id": "hindi_gold_retro",
        "name": "Hindi Gold Classics 24/7",
        "category": "Evergreen Retro MP3",
        "stream_url": "https://azuracast.vibesounds.in:8010/radio.mp3",
        "description": "Non-stop Kishore Kumar, Lata Mangeshkar, and R.D. Burman gems.",
        "bitrate": "128 kbps",
        "is_live": True,
    },
    {
        "id": "lofi_chill_live",
        "name": "Lo-Fi Chillhop Radio",
        "category": "Lo-Fi / Study & Focus",
        "stream_url": "https://streams.ilovemusic.de/iloveradio17.mp3",
        "description": "Peaceful lo-fi beats, gentle ambient rain textures, and chillhop 24/7.",
        "bitrate": "192 kbps HD",
        "is_live": True,
    },
    {
        "id": "top_charts_live",
        "name": "Today Top Chartbusters",
        "category": "Trending Chart Hits",
        "stream_url": "https://streams.ilovemusic.de/iloveradio1.mp3",
        "description": "Non-stop trending chart hits, fresh club anthems, and party beats.",
        "bitrate": "192 kbps HD",
        "is_live": True,
    },
    {
        "id": "bhakti_sagar_live",
        "name": "Bhakti Sagar Divine Live",
        "category": "Devotional / Mantras",
        "stream_url": "http://millenniumhits.out.airtime.pro:8000/millenniumhits_a",
        "description": "Divine morning Bhajans, sacred Sanskrit mantras, and Aarti.",
        "bitrate": "128 kbps",
        "is_live": True,
    },
    {
        "id": "classical_symphonies",
        "name": "Classical Symphonies Live",
        "category": "Classical & Instrumental",
        "stream_url": "https://stream.srg-ssr.ch/m/rsc_de/mp3_128",
        "description": "Timeless symphonies from Mozart, Beethoven, Chopin and Bach.",
        "bitrate": "128 kbps",
        "is_live": True,
    },
    {
        "id": "indie_groove_live",
        "name": "SomaFM Indie Pop & Groove",
        "category": "Indie / Acoustic Groove",
        "stream_url": "https://ice1.somafm.com/groovesalad-128-mp3",
        "description": "A nicely chilled plate of ambient beats, grooves and indie pop.",
        "bitrate": "128 kbps",
        "is_live": True,
    },
]


# ─── Flask App & Route Handlers ──────────────────────────────────────────────
if FLASK_AVAILABLE:
    app = Flask(__name__, template_folder="templates")
    CORS(app)

    @app.route("/")
    def home():
        if os.path.exists("templates/index.html"):
            return render_template("index.html")
        return jsonify({
            "service": "Kalpkrut Beats API Gateway",
            "version": "2.4.0",
            "status": "online",
            "crypto_engine": "PyCryptodome" if PYCRYPTO_AVAILABLE else "Pure-Python DES (Built-in)",
        })

    @app.route("/health", methods=["GET"])
    @app.route("/keepalive", methods=["GET"])
    def health_check():
        return jsonify({
            "status": "online",
            "service": "Kalpkrut Beats API Gateway",
            "version": "2.4.0",
            "crypto_engine": "PyCryptodome" if PYCRYPTO_AVAILABLE else "Pure-Python DES (Built-in)",
            "cached_streams": len(_STREAM_CACHE),
            "cached_hourly": len(_HOURLY_CACHE),
        }), 200

    @app.route("/api/search", methods=["GET"])
    @app.route("/jiosaavn/search", methods=["GET"])
    def search_tracks():
        q = request.args.get("q") or request.args.get("query", "")
        limit = int(request.args.get("limit", 20))
        page = int(request.args.get("p") or request.args.get("page", 1))
        dedup = request.args.get("dedup", "true").lower() in ("true", "1", "yes")

        if not q:
            return jsonify({"tracks": [], "total": 0, "source": "jiosaavn"})

        tracks = _jio_search(q, limit=limit, page=page, dedup=dedup)
        return jsonify({"tracks": tracks, "total": len(tracks), "page": page, "source": "jiosaavn"})

    @app.route("/api/trending", methods=["GET"])
    def trending_tracks():
        limit = int(request.args.get("limit", 20))
        page = int(request.args.get("p") or request.args.get("page", 1))
        lang = (request.args.get("lang") or request.args.get("language") or "all").lower().strip()

        # Hourly cache check for instant speed & regular fresh updates
        cache_key = f"trending:{lang}:p{page}:l{limit}"
        now = time.time()
        if cache_key in _HOURLY_CACHE:
            ts, cached_data = _HOURLY_CACHE[cache_key]
            if now - ts < CACHE_TTL_SECONDS:
                return jsonify(cached_data)

        query_list = LANGUAGE_QUERIES.get(lang, LANGUAGE_QUERIES["all"])
        q_index = (page - 1) % len(query_list)
        page_within_q = ((page - 1) // len(query_list)) + 1
        selected_query = query_list[q_index]

        tracks = _jio_search(selected_query, limit=limit, page=page_within_q, dedup=True)
        resp_data = {
            "tracks": tracks,
            "total": len(tracks),
            "page": page,
            "language": lang,
            "query": selected_query,
            "cached_at": int(now),
            "source": "jiosaavn",
        }
        _HOURLY_CACHE[cache_key] = (now, resp_data)
        return jsonify(resp_data)

    @app.route("/api/play/<track_id>", methods=["GET"])
    @app.route("/jiosaavn/stream", methods=["GET"])
    def play_track(track_id: str = ""):
        tid = track_id or request.args.get("id", "")
        if not tid:
            return jsonify({"error": "Missing track ID"}), 400

        stream_url = _STREAM_CACHE.get(tid)
        if not stream_url:
            track = _jio_get_song_by_id(tid)
            stream_url = track.get("stream_url")

        if stream_url and stream_url.startswith("http"):
            return redirect(stream_url, code=302)

        return jsonify({"error": "Stream not found"}), 404

    @app.route("/api/track/<track_id>", methods=["GET"])
    def get_track_detail(track_id: str):
        track = _jio_get_song_by_id(track_id)
        if track:
            return jsonify(track)
        return jsonify({"error": "Track not found"}), 404

    @app.route("/api/related", methods=["GET"])
    @app.route("/api/recommendations", methods=["GET"])
    def related_tracks():
        """
        Auto-play next song queue logic based on current track.
        Never repeats the current song title or ID.
        """
        song_id = request.args.get("id") or request.args.get("track_id", "")
        title = request.args.get("title", "").strip()
        artist = request.args.get("artist", "").strip()
        limit = int(request.args.get("limit", 15))

        tracks = _jio_get_related(song_id, title, artist, limit=limit)
        return jsonify({
            "tracks": tracks,
            "total": len(tracks),
            "source": "jiosaavn_reco",
        })

    @app.route("/api/radio/stations", methods=["GET"])
    def radio_stations():
        return jsonify({"stations": RADIO_STATIONS, "count": len(RADIO_STATIONS)})

    @app.route("/api/radio/stream/<station_id>", methods=["GET"])
    def radio_stream(station_id: str):
        station = next((s for s in RADIO_STATIONS if s["id"] == station_id), None)
        if not station:
            return jsonify({"error": "Station not found"}), 404
        return redirect(station["stream_url"], code=302)

    # Legacy static files & keepalive
    @app.after_request
    def add_cors_headers(response):
        response.headers["Access-Control-Allow-Origin"] = "*"
        response.headers["Access-Control-Allow-Headers"] = "Content-Type,Authorization"
        response.headers["Access-Control-Allow-Methods"] = "GET,POST,OPTIONS"
        return response

    def _run_keep_alive():
        base_url = os.environ.get("RENDER_EXTERNAL_URL", "https://music-api-tq5i.onrender.com").rstrip("/")
        url = f"{base_url}/keepalive"
        while True:
            time.sleep(600)
            try:
                req = urllib.request.Request(url, headers={"User-Agent": "KeepAlive/1.0"})
                with urllib.request.urlopen(req, timeout=15):
                    pass
            except Exception:
                pass

    threading.Thread(target=_run_keep_alive, daemon=True).start()

else:
    app = None


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    if FLASK_AVAILABLE:
        print(f"Starting Kalpkrut Beats API Gateway on port {port}...")
        app.run(host="0.0.0.0", port=port, debug=False)
