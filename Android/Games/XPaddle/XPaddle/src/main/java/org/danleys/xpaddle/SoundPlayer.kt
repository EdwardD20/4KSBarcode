//
// XPaddle
// SoundPlayer.kt
//

package org.danleys.xpaddle

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import android.util.Log

/// Plays short sound effects by name, looked up as res/raw resources.
/// Mirrors the iOS engines' playMySound(_:), which looked a file up in the
/// app bundle by name and silently skipped playback (after one log line)
/// if it wasn't found. Drop matching files in res/raw (e.g. wall_hit.wav,
/// racquet_hit.wav, golf_clap.wav, aw.wav) to enable sound.
class SoundPlayer(private val context: Context) {
    private val soundPool = SoundPool.Builder()
        .setMaxStreams(4)
        .setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
        ) // setAudioAttributes
        .build()

    private val loadedIds = mutableMapOf<String, Int>()
    private val pendingPlay = mutableSetOf<Int>()
    private val missingWarned = mutableSetOf<String>()

    init {
        soundPool.setOnLoadCompleteListener { pool, id, status ->
            if (status == 0) {
                if (pendingPlay.remove(id)) {
                    pool.play(id, 1f, 1f, 1, 0, 1f)
                } // if this id was awaiting its first playback
            } else {
                pendingPlay.remove(id)
                Log.w("SoundPlayer", "Failed to decode sound (status=$status): resource id $id")
            } // if load succeeded / else
        } // setOnLoadCompleteListener
    } // init

    fun play(resourceName: String) {
        val existingId = loadedIds[resourceName]
        if (existingId != null) {
            soundPool.play(existingId, 1f, 1f, 1, 0, 1f)
            return
        } // if already loaded

        val resId = context.resources.getIdentifier(resourceName, "raw", context.packageName)
        if (resId == 0) {
            if (missingWarned.add(resourceName)) {
                Log.w("SoundPlayer", "Missing sound file: $resourceName")
            } // if not already warned about this name
            return
        } // if resource not found

        val soundId = soundPool.load(context, resId, 1)
        loadedIds[resourceName] = soundId
        pendingPlay.add(soundId)
    } // play

    fun release() {
        soundPool.release()
    } // release
} // class SoundPlayer
