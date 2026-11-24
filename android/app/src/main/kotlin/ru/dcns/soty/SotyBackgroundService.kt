// A foreground service that keeps the Soty process cached-alive and free of
// Doze freezes so the mesh radios and the relay connections keep working while
// the app is not on screen. START_STICKY lets the system restart it after a
// kill. The persistent notification is the user-visible, user-stoppable part
// (Android requires a foreground service to announce itself in the tray).
package ru.dcns.soty

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class SotyBackgroundService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startAsForeground()
        return START_STICKY
    }

    private fun startAsForeground() {
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // The mesh is the always-on part (BLE/Wi-Fi Direct), so the
            // service starts as connectedDevice: this type has no time cap,
            // unlike dataSync (Android 15+ caps dataSync at 6 hours).
            ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
        } else {
            0
        }
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(notifId, notification, type)
        } else {
            startForeground(notifId, notification)
        }
    }

    // Android 15+ calls this when the dataSync part of the service outlives
    // its 6-hour budget. The mesh (connectedDevice) keeps running-owned; a
    // fresh sync starts the next time the app is foregrounded or (with a push
    // channel, see the README Play section) woken remotely.
    override fun onTimeout(startId: Int, fgsType: Int) {
        super.onTimeout(startId, fgsType)
        stopSelf(startId)
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                channelId,
                getString(R.string.soty_bg_channel),
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = getString(R.string.soty_bg_channel_desc)
            },
        )
    }

    private fun buildNotification(): Notification {
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(getString(R.string.soty_bg_notification))
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    companion object {
        private const val channelId = "soty_bg"
        private const val notifId = 0x2a17

        fun start(context: Context) {
            context.startForegroundService(Intent(context, SotyBackgroundService::class.java))
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, SotyBackgroundService::class.java))
        }
    }
}