package com.example.massngertest

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import androidx.core.app.NotificationCompat

class SmsReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            if (messages.isNotEmpty()) {
                val sender = messages[0].displayOriginatingAddress
                val body = messages.joinToString(separator = "") { it.messageBody }
                
                // نمایش نوتیفیکیشن
                showNotification(context, sender, body)
            }
        }
    }

    private fun showNotification(context: Context, sender: String, body: String) {
        val channelId = "sms_channel"
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // ساخت کانال برای اندروید 8 به بالا
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Incoming SMS",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for incoming messages"
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        // اینتنت برای باز کردن برنامه وقتی روی نوتیفیکیشن کلیک شد
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingIntent = PendingIntent.getActivity(
            context, 
            0, 
            intent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.stat_notify_chat) // آیکون پیش‌فرض (بعدا آیکون خودت را بگذار)
            .setContentTitle(sender)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)

        notificationManager.notify(System.currentTimeMillis().toInt(), builder.build())
    }
}
