from flask import Flask, request, jsonify, send_from_directory, render_template, redirect
from flask_cors import CORS
import os
import re
import sys
import time
import uuid
import html
import subprocess
import threading
import urllib.request
import urllib.parse
import json
import base64
import yt_dlp

try:
    from Crypto.Cipher import DES
    CRYPTO_AVAILABLE = True
except ImportError:
    CRYPTO_AVAILABLE = False

app = Flask(__name__, template_folder="templates")
CORS(app)

DOWNLOAD_FOLDER = "static"
COOKIES_FILE = "cookies.txt"

if not os.path.exists(DOWNLOAD_FOLDER):
    os.makedirs(DOWNLOAD_FOLDER)

# In-memory stream URL cache: {track_id: stream_url}
_STREAM_CACHE = {}


# ─── Helpers ──────────────────────────────────────────────────────────────────

def delete_old_files():
    """Delete static files older than 30 minutes."""
    for file in os.listdir(DOWNLOAD_FOLDER):
        file_path = os.path.join(DOWNLOAD_FOLDER, file)
        if os.path.isfile(file_path) and time.time() - os.path.getctime(file_path) > 1800:
            try:
                os.remove(file_path)
            except Exception:
                pass


def _jio_decrypt(encrypted_url: str) -> str:
    """Decrypt a JioSaavn encrypted media URL using DES-ECB."""
    if not CRYPTO_AVAILABLE or not encrypted_url:
        return ""
    try:
        key = b"38346591"
        enc = encrypted_url.replace("_", "/").replace("-", "+")
        enc += "=" * (-len(enc) % 4)
        enc_bytes = base64.b64decode(enc)
        cipher = DES.new(key, DES.MODE_ECB)
        dec = cipher.decrypt(enc_bytes)
        # Remove PKCS5 padding and null bytes
        dec = dec.rstrip(b"\x00\x01\x02\x03\x04\x05\x06\x07\x08\t\n\x0b\x0c\r\x0e\x0f\x10")
        dec = dec.decode("utf-8", errors="ignore").strip()
        dec = dec.replace("http:", "https:")
        dec = re.sub(r"_96\.mp4", "_320.mp4", dec)
        dec = re.sub(r"_160\.mp4", "_320.mp4", dec)
        return dec
    except Exception:
        return ""


_JIO_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "application/json, text/plain, */*",
    "Referer": "https://www.jiosaavn.com/",
}


def _jio_get(url: str, timeout: int = 15) -> dict:
    req = urllib.request.Request(url, headers=_JIO_HEADERS)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8", errors="ignore"))


def _jio_search(query: str, limit: int = 20, page: int = 1) -> list:
    """Search JioSaavn using search.getResults for rich metadata & direct streams."""
    try:
        url = (
            f"https://www.jiosaavn.com/api.php?__call=search.getResults"
            f"&_format=json&_marker=0&api_version=4&ctx=wap6dot0"
            f"&q={urllib.parse.quote(query)}&p={page}&n={limit}"
        )
        data = _jio_get(url)
        results = data.get("results", [])
        tracks = []
        for r in results:
            if not r:
                continue
            tid = r.get("id", "")
            more = r.get("more_info", {})
            enc = more.get("encrypted_media_url", "")
            stream_url = _jio_decrypt(enc) if enc else ""
            if stream_url and tid:
                _STREAM_CACHE[tid] = stream_url

            title = html.unescape(r.get("title", "") or r.get("song", "") or "Unknown Title")
            artist = html.unescape(r.get("subtitle", "") or more.get("music", "") or "Unknown Artist")
            album = html.unescape(more.get("album", "") or "Single")
            img = (r.get("image") or "").replace("150x150", "500x500").replace("http:", "https:")

            try:
                duration_sec = int(more.get("duration", 0) or 0)
            except Exception:
                duration_sec = 0

            tracks.append({
                "id": tid,
                "title": title,
                "artist": artist,
                "album": album,
                "artwork_url": img,
                "thumbnail": img,
                "duration_ms": duration_sec * 1000,
                "duration": duration_sec,
                "stream_url": stream_url,
                "download_url": stream_url,
                "source": "jiosaavn",
            })
        return tracks
    except Exception as e:
        print(f"[_jio_search error] {e}")
        return []


# ─── Routes ───────────────────────────────────────────────────────────────────

@app.route("/")
def home():
    return render_template("index.html")


# ─── Health & Keepalive ───────────────────────────────────────────────────────
# CustomApiProvider checks data['status'] == 'online'
@app.route("/health", methods=["GET"])
@app.route("/keepalive", methods=["GET"])
def health_check():
    return jsonify({
        "status": "online",
        "service": "Music API Gateway",
        "version": "2.3.0",
        "message": "Server is alive!",
    }), 200


# ─── /api/search — Main search used by Flutter CustomApiProvider ─────────────
@app.route("/api/search", methods=["GET"])
@app.route("/jiosaavn/search", methods=["GET"])
def search_tracks():
    q = request.args.get("q") or request.args.get("query", "")
    limit = int(request.args.get("limit", 20))
    page = int(request.args.get("p", 1))
    if not q:
        return jsonify({"tracks": []})

    tracks = _jio_search(q, limit=limit, page=page)
    return jsonify({
        "tracks": tracks,
        "source": "jiosaavn",
        "total": len(tracks),
    })


# ─── /api/trending — Top hits for Flutter home screen ─────────────────────────
@app.route("/api/trending", methods=["GET"])
def trending_tracks():
    limit = int(request.args.get("limit", 20))
    tracks = _jio_search("Latest Bollywood Hits", limit=limit)
    if not tracks:
        tracks = _jio_search("Trending Hindi", limit=limit)
    return jsonify({
        "tracks": tracks,
        "total": len(tracks),
    })


# ─── /api/play/<track_id> — Direct audio stream redirect ─────────────────────
# Returns 302 redirect directly to the high-bitrate Saavn CDN file so just_audio
# plays instantly with hardware acceleration and seeking.
@app.route("/api/play/<track_id>", methods=["GET"])
def play_track(track_id):
    stream_url = _STREAM_CACHE.get(track_id)
    if not stream_url:
        try:
            detail_url = (
                f"https://www.jiosaavn.com/api.php?__call=song.getDetails"
                f"&cc=in&_marker=0&_format=json&pids={track_id}"
            )
            data = _jio_get(detail_url)
            song = data.get(track_id, {})
            enc = song.get("encrypted_media_url", "")
            stream_url = _jio_decrypt(enc)
            if stream_url:
                _STREAM_CACHE[track_id] = stream_url
        except Exception:
            pass

    if stream_url:
        return redirect(stream_url, code=302)
    return jsonify({"error": "Stream not found"}), 404


# ─── /api/track/<track_id> — Single track metadata ────────────────────────────
@app.route("/api/track/<track_id>", methods=["GET"])
def get_track_detail(track_id):
    try:
        detail_url = (
            f"https://www.jiosaavn.com/api.php?__call=song.getDetails"
            f"&cc=in&_marker=0&_format=json&pids={track_id}"
        )
        data = _jio_get(detail_url)
        song = data.get(track_id, {})
        if not song:
            return jsonify({"error": "Track not found"}), 404

        enc = song.get("encrypted_media_url", "")
        stream_url = _jio_decrypt(enc)
        if stream_url:
            _STREAM_CACHE[track_id] = stream_url

        title = html.unescape(song.get("song", "") or "Unknown")
        artist = html.unescape(song.get("primary_artists", "") or "")
        album = html.unescape(song.get("album", "") or "")
        img = (song.get("image") or "").replace("150x150", "500x500").replace("http:", "https:")

        try:
            duration_sec = int(song.get("duration", 0) or 0)
        except Exception:
            duration_sec = 0

        return jsonify({
            "id": track_id,
            "title": title,
            "artist": artist,
            "album": album,
            "artwork_url": img,
            "thumbnail": img,
            "duration_ms": duration_sec * 1000,
            "stream_url": stream_url,
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ─── /jiosaavn/stream — Legacy compatibility endpoint ─────────────────────────
@app.route("/jiosaavn/stream", methods=["GET"])
def jiosaavn_stream():
    song_id = request.args.get("id", "")
    if not song_id:
        return jsonify({"error": "No song ID provided"}), 400
    return play_track(song_id)


# ─── /stream — YouTube direct CDN URL (no file download) ──────────────────────
@app.route("/stream", methods=["GET"])
def stream_audio():
    video_url = request.args.get("url") or request.args.get("video_url")
    if not video_url:
        return jsonify({"error": "No URL provided"}), 400

    ydl_opts = {
        "format": "bestaudio[ext=m4a]/bestaudio/best",
        "quiet": True,
        "no_warnings": True,
        "noplaylist": True,
    }
    if os.path.exists(COOKIES_FILE):
        ydl_opts["cookiefile"] = COOKIES_FILE

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(video_url, download=False)

        stream_url = info.get("url")
        if not stream_url and "formats" in info:
            fmts = [f for f in info["formats"] if f.get("vcodec") == "none" and f.get("acodec") != "none"]
            if fmts:
                fmts.sort(key=lambda f: f.get("abr", 0) or 0, reverse=True)
                stream_url = fmts[0]["url"]
            else:
                stream_url = info["formats"][-1]["url"]

        if not stream_url:
            return jsonify({"error": "Could not extract stream URL"}), 500

        return jsonify({
            "stream_url": stream_url,
            "title": info.get("title", ""),
            "thumbnail": info.get("thumbnail", ""),
            "duration": info.get("duration", 0),
            "uploader": info.get("uploader", ""),
        })

    except yt_dlp.utils.DownloadError as e:
        return jsonify({"error": f"yt-dlp error: {str(e)}"}), 500
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ─── /search — Search YouTube for tracks ──────────────────────────────────────
@app.route("/search", methods=["GET"])
def search_youtube():
    query = request.args.get("q") or request.args.get("query", "")
    limit = int(request.args.get("limit", 10))
    if not query:
        return jsonify({"error": "No query provided"}), 400

    ydl_opts = {
        "quiet": True,
        "no_warnings": True,
        "extract_flat": True,
        "noplaylist": True,
    }
    if os.path.exists(COOKIES_FILE):
        ydl_opts["cookiefile"] = COOKIES_FILE

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            result = ydl.extract_info(f"ytsearch{limit}:{query}", download=False)

        tracks = []
        for entry in (result.get("entries") or []):
            if not entry:
                continue
            vid_id = entry.get("id", "")
            tracks.append({
                "id": vid_id,
                "title": entry.get("title", ""),
                "url": f"https://www.youtube.com/watch?v={vid_id}",
                "thumbnail": entry.get("thumbnail") or f"https://i.ytimg.com/vi/{vid_id}/hqdefault.jpg",
                "duration": entry.get("duration", 0),
                "uploader": entry.get("uploader") or entry.get("channel", ""),
            })
        return jsonify({"tracks": tracks})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ─── /download — Legacy YouTube file downloader ───────────────────────────────
@app.route("/download", methods=["GET"])
def download_audio():
    delete_old_files()
    video_url = request.args.get("url")
    media_type = request.args.get("type", "audio")

    if not video_url:
        return jsonify({"error": "No URL provided"}), 400

    file_id = str(uuid.uuid4())

    if media_type == "audio":
        output_template = os.path.join(DOWNLOAD_FOLDER, f"{file_id}.%(ext)s")
        expected_filename = f"{file_id}.mp3"
        command = [
            "yt-dlp",
            "-x",
            "--audio-format", "mp3",
            "--audio-quality", "0",
            "-o", output_template,
        ]
    elif media_type == "video":
        output_template = os.path.join(DOWNLOAD_FOLDER, f"{file_id}.%(ext)s")
        expected_filename = f"{file_id}.mp4"
        command = [
            "yt-dlp",
            "-f", "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best",
            "-o", output_template,
        ]
    else:
        return jsonify({"error": "Invalid type. Must be 'audio' or 'video'"}), 400

    if os.path.exists(COOKIES_FILE):
        command.extend(["--cookies", COOKIES_FILE])

    command.append(video_url)

    try:
        subprocess.run(command, check=True)
        file_url = f"{request.host_url}{DOWNLOAD_FOLDER}/{expected_filename}"
        return jsonify({"file_url": file_url, "message": "Download successful"})
    except subprocess.CalledProcessError as e:
        return jsonify({"error": str(e)}), 500


# ─── Static file serving ──────────────────────────────────────────────────────
@app.route("/static/<filename>")
def serve_static(filename):
    return send_from_directory(DOWNLOAD_FOLDER, filename)


@app.route("/channel", methods=["GET"])
def get_channel():
    return jsonify({"channel_link": "https://m.youtube.com/mirrykal"})


@app.after_request
def add_header(response):
    response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
    return response


def _run_keep_alive():
    base_url = os.environ.get("RENDER_EXTERNAL_URL", "https://music-api-tq5i.onrender.com").rstrip("/")
    url = f"{base_url}/keepalive"
    while True:
        time.sleep(600)
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "KeepAlive/1.0"})
            with urllib.request.urlopen(req, timeout=15) as resp:
                pass
        except Exception:
            pass


threading.Thread(target=_run_keep_alive, daemon=True).start()


def uvicorn_fallback():
    """Fallback runner if Render Start Command is set to 'uvicorn server.py'."""
    port = os.environ.get("PORT", "5000")
    try:
        cmd = ["gunicorn", "-b", f"0.0.0.0:{port}", "server:app"]
        os.execvp("gunicorn", cmd)
    except Exception:
        app.run(host="0.0.0.0", port=int(port))


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)
