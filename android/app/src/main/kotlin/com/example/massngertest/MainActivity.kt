package com.example.massngertest

import android.app.PendingIntent
import android.app.role.RoleManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.provider.Telephony
import android.telephony.SmsManager
import android.telephony.SubscriptionInfo
import android.telephony.SubscriptionManager
import android.widget.Toast
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {

    private val CHANNEL = "com.example.messages/sms"
    private val SENT_ACTION = "SMS_SENT"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendSms" -> {
                    val address = call.argument<String>("address")
                    val body = call.argument<String>("body")
                    val subId = call.argument<Int>("subId")
                    
                    if (address != null && body != null) {
                        sendSMS(address, body, subId)
                        result.success("Sent")
                    } else {
                        result.error("INVALID_ARGS", "Address or body is null", null)
                    }
                }
                "isDefaultSms" -> result.success(isDefaultSmsApp())
                "requestDefaultSms" -> {
                    requestDefaultSmsApp()
                    result.success(true)
                }
                "getSimCards" -> result.success(getSimCardsInfo())
                "markAsRead" -> {
                    val id = call.argument<String>("id")
                    if (id != null) {
                        markSmsAsRead(id)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Id is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun sendSMS(address: String, body: String, subId: Int?) {
        try {
            val smsManager = if (subId != null && subId != SubscriptionManager.INVALID_SUBSCRIPTION_ID) {
                SmsManager.getSmsManagerForSubscriptionId(subId)
            } else {
                SmsManager.getDefault()
            }

            // اینتنت برای بررسی وضعیت ارسال
            val sentIntent = PendingIntent.getBroadcast(
                this, 0, Intent(SENT_ACTION), 
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val parts = smsManager.divideMessage(body)
            // اگر پیام چند بخشی بود، برای همه بخش‌ها اینتنت ارسال ست می‌شود
            val sentIntents = ArrayList<PendingIntent>()
            for (i in parts.indices) sentIntents.add(sentIntent)

            smsManager.sendMultipartTextMessage(address, null, parts, sentIntents, null)
            
        } catch (e: Exception) {
            e.printStackTrace()
            Toast.makeText(this, "Error initiating SMS: ${e.message}", Toast.LENGTH_SHORT).show()
        }
    }
    
    // رجیستر کردن رسیور برای فهمیدن نتیجه ارسال
    override fun onResume() {
        super.onResume()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(sentReceiver, IntentFilter(SENT_ACTION), Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(sentReceiver, IntentFilter(SENT_ACTION))
        }
    }

    override fun onPause() {
        super.onPause()
        try {
            unregisterReceiver(sentReceiver)
        } catch (e: Exception) {}
    }

    private val sentReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (resultCode) {
                android.app.Activity.RESULT_OK -> {
                    // پیام با موفقیت به شبکه مخابرات تحویل داده شد
                    // (اختیاری: اینجا نیازی به نوتیفیکیشن نیست چون کاربر خودش فرستاده)
                }
                SmsManager.RESULT_ERROR_GENERIC_FAILURE,
                SmsManager.RESULT_ERROR_NO_SERVICE,
                SmsManager.RESULT_ERROR_NULL_PDU,
                SmsManager.RESULT_ERROR_RADIO_OFF -> {
                    // خطا در ارسال!
                    Toast.makeText(context, "Message Failed to Send! Check credit/signal.", Toast.LENGTH_LONG).show()
                }
            }
        }
    }

    private fun markSmsAsRead(id: String) {
        try {
            val uri = android.net.Uri.parse("content://sms/$id")
            val values = android.content.ContentValues()
            values.put("read", true)
            contentResolver.update(uri, values, null, null)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun isDefaultSmsApp(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(RoleManager::class.java)
            roleManager.isRoleHeld(RoleManager.ROLE_SMS)
        } else {
            Telephony.Sms.getDefaultSmsPackage(this) == packageName
        }
    }

    private fun requestDefaultSmsApp() {
        if (isDefaultSmsApp()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(RoleManager::class.java)
            val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_SMS)
            startActivityForResult(intent, 123)
        } else {
            val intent = Intent(Telephony.Sms.Intents.ACTION_CHANGE_DEFAULT)
            intent.putExtra(Telephony.Sms.Intents.EXTRA_PACKAGE_NAME, packageName)
            startActivity(intent)
        }
    }

    private fun getSimCardsInfo(): List<Map<String, Any>> {
        val subscriptionManager = getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
        val activeSubscriptionInfoList: List<SubscriptionInfo>? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
            subscriptionManager.activeSubscriptionInfoList
        } else {
            null
        }
        val sims = mutableListOf<Map<String, Any>>()
        if (activeSubscriptionInfoList != null) {
            for (subscriptionInfo in activeSubscriptionInfoList) {
                val sim = mapOf(
                    "id" to subscriptionInfo.subscriptionId,
                    "slot" to subscriptionInfo.simSlotIndex,
                    "carrier" to subscriptionInfo.displayName.toString()
                )
                sims.add(sim)
            }
        }
        return sims;
    }
}
