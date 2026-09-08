package kr.hs.ghas.ghason

import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class GhasFirebaseMessagingService : FirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        val title = message.data["title"].nonBlankOrNull()
            ?: message.notification?.title.nonBlankOrNull()
            ?: getString(R.string.meal_notification_title)
        val body = message.data["body"].nonBlankOrNull()
            ?: message.notification?.body.nonBlankOrNull()
            ?: getString(R.string.meal_notification_body_fallback)

        NativeNotificationScheduler(applicationContext)
            .displayLegacyMealNotification(title, body)
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d(TAG, "FCM token refreshed; TODO: sync the token when backend delivery is added.")
    }

    private fun String?.nonBlankOrNull(): String? =
        this?.trim()?.takeIf { it.isNotEmpty() }

    companion object {
        private const val TAG = "GHASMessaging"
    }
}
