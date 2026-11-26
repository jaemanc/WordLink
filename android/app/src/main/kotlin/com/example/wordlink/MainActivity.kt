package com.example.wordlink

import android.media.AudioAttributes
import android.media.SoundPool
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

class MainActivity : FlutterActivity() {
    private var impactChannel: MethodChannel? = null
    private var impactSoundPool: SoundPool? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val pool = SoundPool.Builder()
            .setMaxStreams(1)
            .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME).build())
            .build()
        impactSoundPool = pool
        var ready: Boolean? = null
        var pendingVolume: Float? = null
        pool.setOnLoadCompleteListener { _, sound, status ->
            ready = status == 0
            if (ready == true) {
                pendingVolume?.let { pool.play(sound, it, it, 1, 0, 1f) }
            }
            pendingVolume = null
        }

        val asset = FlutterInjector.instance().flutterLoader()
            .getLookupKeyForAsset("assets/craft_impact.wav")
        val sound = try {
            assets.openFd(asset).use { pool.load(it, 1) }
        } catch (_: IOException) {
            0
        }
        impactChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "wordlink/impact")
            .also { channel ->
                channel.setMethodCallHandler { call, reply ->
                    if (call.method != "play" || sound == 0 || ready == false) {
                        reply.notImplemented()
                    } else {
                        val volume = if (call.arguments == true) 1f else 0.75f
                        if (ready == true) {
                            pool.play(sound, volume, volume, 1, 0, 1f)
                        } else {
                            pendingVolume = volume
                        }
                        reply.success(null)
                    }
                }
            }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        impactChannel?.setMethodCallHandler(null)
        impactChannel = null
        impactSoundPool?.release()
        impactSoundPool = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
