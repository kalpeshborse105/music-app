package com.echoflowmusic.player

import android.content.ContentUris
import android.provider.MediaStore
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter UI and bridges the device's MediaStore audio library to
 * Dart for the Local Music provider.
 *
 * Extends [AudioServiceActivity] so the background audio service shares the
 * same Flutter engine and can drive playback + media notifications.
 */
class MainActivity : AudioServiceActivity() {

    private companion object {
        const val CHANNEL = "com.echoflowmusic.player/media"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "queryAudio" -> {
                        try {
                            result.success(queryAudio())
                        } catch (e: SecurityException) {
                            result.error("PERMISSION", e.message, null)
                        } catch (e: Exception) {
                            result.error("QUERY_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Reads the user's own audio files from MediaStore. Nothing is uploaded. */
    private fun queryAudio(): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        val collection = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.ALBUM_ID,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.IS_MUSIC,
            MediaStore.Audio.Media.DATA,
        )
        val selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0"
        val sortOrder = "${MediaStore.Audio.Media.TITLE} ASC"

        contentResolver.query(collection, projection, selection, null, sortOrder)?.use { cursor ->
            val idCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val titleCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val artistCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val albumCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
            val albumIdCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)
            val durCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
            val dataCol = cursor.getColumnIndex(MediaStore.Audio.Media.DATA)

            while (cursor.moveToNext()) {
                val id = cursor.getLong(idCol)
                val contentUri = ContentUris.withAppendedId(collection, id)
                val albumId = cursor.getLong(albumIdCol)
                val artUri = ContentUris.withAppendedId(
                    android.net.Uri.parse("content://media/external/audio/albumart"),
                    albumId
                )
                val map = HashMap<String, Any?>()
                map["id"] = id.toString()
                map["title"] = cursor.getString(titleCol)
                map["artist"] = cursor.getString(artistCol)
                map["album"] = cursor.getString(albumCol)
                map["albumId"] = albumId.toString()
                map["duration"] = cursor.getLong(durCol)
                map["uri"] = contentUri.toString()
                map["albumArtUri"] = artUri.toString()
                if (dataCol >= 0) {
                    map["path"] = cursor.getString(dataCol)
                }
                out.add(map)
            }
        }
        return out
    }
}
