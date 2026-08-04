package com.onionchat.onionchat_mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat

/**
 * Foreground service that keeps Tor running in the background.
 * This allows the app to maintain Tor connections and hidden services
 * while the app is minimized or in the background.
 */
class TorForegroundService : Service() {

    companion object {
        private const val CHANNEL_ID = "tor_background_channel"
        private const val NOTIFICATION_ID = 1001
        const val ACTION_START = "START_TOR_SERVICE"
        const val ACTION_STOP = "STOP_TOR_SERVICE"
    }

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        acquireWakeLock()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action

        when (action) {
            ACTION_START -> {
                startForegroundService()
            }
            ACTION_STOP -> {
                stopForegroundService()
            }
        }

        return START_STICKY
    }

    private fun startForegroundService() {
        val notification = buildNotification("Tor running in background", "Hidden services and connections are active")
        startForeground(NOTIFICATION_ID, notification)
    }

    private fun stopForegroundService() {
        stopForeground(true)
        releaseWakeLock()
        stopSelf()
    }

    private fun buildNotification(title: String, text: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(R.drawable.ic_stat_onionchat)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Tor Background Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps Tor running for background connections and hidden services"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            }

            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun acquireWakeLock() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "TorForegroundService::WakeLock"
        ).apply {
            acquire()
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.release()
        wakeLock = null
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        releaseWakeLock()
        stopForeground(true)
        super.onDestroy()
    }
}