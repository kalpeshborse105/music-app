package com.echoflowmusic.player

import com.ryanheise.audioservice.AudioService as BaseAudioService

/**
 * Concrete [BaseAudioService] for EchoFlow Music.
 *
 * Declared in AndroidManifest.xml as a mediaPlayback foreground service so
 * audio keeps playing when the app is backgrounded and exposes a
 * MediaSessionCompat used for lock-screen / headset / notification controls.
 */
class AudioService : BaseAudioService()
