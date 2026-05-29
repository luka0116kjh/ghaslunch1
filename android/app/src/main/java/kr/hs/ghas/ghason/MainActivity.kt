package kr.hs.ghas.ghason

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.app.AlertDialog
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.text.InputFilter
import android.text.InputType
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.RadioButton
import android.widget.RadioGroup
import android.widget.ScrollView
import android.widget.Switch
import android.widget.TextView
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.edit
import androidx.core.graphics.toColorInt
import androidx.core.net.toUri
import com.google.firebase.messaging.FirebaseMessaging
import java.util.Locale

class MainActivity : ComponentActivity() {
    private lateinit var webView: WebView
    private lateinit var preferences: SharedPreferences
    private lateinit var fileChooserLauncher: ActivityResultLauncher<Intent>
    private lateinit var notificationPermissionLauncher: ActivityResultLauncher<String>
    private lateinit var notificationSettingsIcon: ImageView
    private val nativeBridge by lazy { NativeNotificationBridge(this) }
    private val notificationScheduler by lazy { NativeNotificationScheduler(applicationContext) }
    private var fileChooserCallback: ValueCallback<Array<Uri>>? = null
    private var bridgeAttached = false
    private var barcodeScanModeEnabled = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        registerActivityResultLaunchers()
        notificationScheduler.createNotificationChannels()
        syncLegacyMealTopicSubscription()

        preferences = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        webView = WebView(this).apply {
            configureSettings(settings)
            webViewClient = createWebViewClient()
            webChromeClient = createWebChromeClient()
        }

        val contentView = FrameLayout(this).apply {
            addView(webView)
            addView(createNotificationSettingsButton())
        }
        setContentView(contentView)
        registerBackHandler()
        updateNativeBridge(APP_URL)
        webView.loadUrl(APP_URL)
    }

    private fun registerBackHandler() {
        onBackPressedDispatcher.addCallback(
            this,
            object : OnBackPressedCallback(true) {
                override fun handleOnBackPressed() {
                    disableBarcodeScanMode()
                    if (::webView.isInitialized && webView.canGoBack()) {
                        webView.goBack()
                    } else {
                        finish()
                    }
                }
            }
        )
    }

    private fun registerActivityResultLaunchers() {
        fileChooserLauncher = registerForActivityResult(
            ActivityResultContracts.StartActivityForResult()
        ) { result ->
            val results = if (result.resultCode == Activity.RESULT_OK) {
                result.data?.let { collectFileChooserResults(it) } ?: emptyArray()
            } else {
                null
            }
            fileChooserCallback?.onReceiveValue(results)
            fileChooserCallback = null
        }

        notificationPermissionLauncher = registerForActivityResult(
            ActivityResultContracts.RequestPermission()
        ) { granted ->
            if (granted) {
                notificationScheduler.scheduleSelectedNotifications()
                syncLegacyMealTopicSubscription()
                updateWebNotificationState(true)
                Toast.makeText(this, R.string.notification_enabled, Toast.LENGTH_SHORT).show()
            } else {
                notificationScheduler.setMasterEnabled(false)
                notificationScheduler.cancelAllLocalNotifications()
                unsubscribeFromLegacyMealTopic()
                updateWebNotificationState(false)
                Toast.makeText(
                    this,
                    R.string.notification_permission_denied,
                    Toast.LENGTH_SHORT
                )
                    .show()
            }
        }

    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun configureSettings(settings: WebSettings) {
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.useWideViewPort = true
        settings.loadWithOverviewMode = true
        settings.builtInZoomControls = false
        settings.displayZoomControls = false
        settings.setSupportZoom(false)
    }

    private fun createWebViewClient(): WebViewClient {
        return object : WebViewClient() {
            override fun shouldOverrideUrlLoading(
                view: WebView,
                request: WebResourceRequest
            ): Boolean = handleUrl(request.url)

            @Deprecated("Deprecated by Android WebView, still called on older devices.")
            override fun shouldOverrideUrlLoading(view: WebView, url: String): Boolean {
                return handleUrl(url.toUri())
            }

            override fun onPageStarted(view: WebView, url: String?, favicon: Bitmap?) {
                disableBarcodeScanMode()
                updateNativeBridge(url)
                Log.d(TAG, "Loading $url")
            }

            override fun onPageFinished(view: WebView, url: String?) {
                applySavedThemeToPage()
                syncNativeThemeFromPage()
            }

            override fun onReceivedError(
                view: WebView,
                request: WebResourceRequest,
                error: WebResourceError
            ) {
                if (request.isForMainFrame) {
                    Log.e(TAG, "WebView error ${error.errorCode}: ${error.description}")
                }
            }

            override fun onReceivedHttpError(
                view: WebView,
                request: WebResourceRequest,
                errorResponse: WebResourceResponse
            ) {
                if (request.isForMainFrame) {
                    Log.e(TAG, "HTTP ${errorResponse.statusCode} while loading ${request.url}")
                }
            }
        }
    }

    private fun createWebChromeClient(): WebChromeClient {
        return object : WebChromeClient() {
            override fun onShowFileChooser(
                webView: WebView,
                filePathCallback: ValueCallback<Array<Uri>>,
                fileChooserParams: FileChooserParams
            ): Boolean {
                this@MainActivity.fileChooserCallback?.onReceiveValue(null)
                this@MainActivity.fileChooserCallback = filePathCallback

                val acceptTypes = fileChooserParams.acceptTypes
                    ?.filter { it.isNotBlank() }
                    ?.toTypedArray()
                    ?: emptyArray()
                val mimeType = acceptTypes.firstOrNull()
                    ?.takeIf { it != "*/*" }
                    ?: "image/*"

                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = mimeType
                    putExtra(Intent.EXTRA_MIME_TYPES, acceptTypes.ifEmpty { arrayOf("image/*") })
                    putExtra(
                        Intent.EXTRA_ALLOW_MULTIPLE,
                        fileChooserParams.mode == FileChooserParams.MODE_OPEN_MULTIPLE
                    )
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                }

                return try {
                    fileChooserLauncher.launch(intent)
                    true
                } catch (error: ActivityNotFoundException) {
                    Log.e(TAG, "No activity can choose an image", error)
                    this@MainActivity.fileChooserCallback = null
                    filePathCallback.onReceiveValue(null)
                    false
                }
            }
        }
    }

    private fun handleUrl(uri: Uri?): Boolean {
        if (uri == null) {
            return true
        }

        return when (uri.scheme?.lowercase()) {
            "http", "https" -> {
                updateNativeBridge(uri.toString())
                false
            }
            "mailto", "tel", "sms", "geo" -> {
                openExternally(uri)
                true
            }
            else -> {
                Log.w(TAG, "Blocked unsupported URL scheme: $uri")
                true
            }
        }
    }

    private fun updateNativeBridge(url: String?) {
        val trusted = url?.let { isTrustedAppUri(it.toUri()) } ?: false
        if (trusted && !bridgeAttached) {
            webView.addJavascriptInterface(nativeBridge, "GHASAndroidApp")
            webView.addJavascriptInterface(nativeBridge, "GHASAndroidNotifications")
            webView.addJavascriptInterface(nativeBridge, "AndroidBridge")
            bridgeAttached = true
        } else if (!trusted && bridgeAttached) {
            disableBarcodeScanMode()
            webView.removeJavascriptInterface("GHASAndroidApp")
            webView.removeJavascriptInterface("GHASAndroidNotifications")
            webView.removeJavascriptInterface("AndroidBridge")
            bridgeAttached = false
        }
    }

    private fun isTrustedAppUri(uri: Uri): Boolean {
        if (uri.scheme?.lowercase() != "https") {
            return false
        }

        return uri.host.equals("ghaslunch1.web.app", ignoreCase = true) ||
            uri.host.equals("ghaslunch1.firebaseapp.com", ignoreCase = true)
    }

    private fun openExternally(uri: Uri) {
        try {
            startActivity(Intent(Intent.ACTION_VIEW, uri))
        } catch (error: ActivityNotFoundException) {
            Log.e(TAG, "No activity can open $uri", error)
            Toast.makeText(this, R.string.external_link_error, Toast.LENGTH_SHORT).show()
        }
    }

    private fun createNotificationSettingsButton(): View {
        val ripple = TypedValue()
        theme.resolveAttribute(android.R.attr.selectableItemBackgroundBorderless, ripple, true)
        return ImageView(this).apply {
            notificationSettingsIcon = this
            setImageResource(R.drawable.ic_notifications)
            scaleType = ImageView.ScaleType.FIT_CENTER
            contentDescription = getString(R.string.notification_settings_title)
            isClickable = true
            isFocusable = true
            setBackgroundResource(ripple.resourceId)
            setColorFilter(nativePalette().accent)
            setOnClickListener { showNotificationSettingsDialog() }
            val padding = dp(NOTIFICATION_ICON_PADDING_DP)
            setPadding(padding, padding, padding, padding)
            layoutParams = FrameLayout.LayoutParams(
                dp(NOTIFICATION_ICON_TOUCH_SIZE_DP),
                dp(NOTIFICATION_ICON_TOUCH_SIZE_DP),
                Gravity.END or Gravity.TOP
            ).apply {
                setMargins(0, dp(NOTIFICATION_ICON_TOP_MARGIN_DP), dp(NOTIFICATION_ICON_SIDE_MARGIN_DP), 0)
            }
        }
    }

    private fun showNotificationSettingsDialog() {
        val palette = nativePalette()
        val current = notificationScheduler.settings()
        var mealTime = current.mealTime
        var timetableTime = current.timetableTime
        var schoolNoticeTime = current.schoolNoticeTime

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(22), dp(18), dp(22), dp(10))
            addView(createDialogTitle(R.string.notification_settings_title, palette))
        }
        val masterSwitch = createNotificationSwitch(
            R.string.notification_master_enabled,
            current.enabled,
            palette
        )
        val mealSwitch = createNotificationSwitch(
            R.string.notification_meal_enabled,
            current.mealEnabled,
            palette
        )
        val mealTimeButton = createNotificationTimeButton(
            R.string.notification_meal_time,
            mealTime,
            palette
        )
        val timetableSwitch = createNotificationSwitch(
            R.string.notification_timetable_enabled,
            current.timetableEnabled,
            palette
        )
        val timetableTimeButton = createNotificationTimeButton(
            R.string.notification_timetable_time,
            timetableTime,
            palette
        )
        val schoolNoticeSwitch = createNotificationSwitch(
            R.string.notification_school_notice_enabled,
            current.schoolNoticeEnabled,
            palette
        )
        val schoolNoticeTimeButton = createNotificationTimeButton(
            R.string.notification_school_notice_time,
            schoolNoticeTime,
            palette
        )

        content.addView(masterSwitch)
        content.addView(mealSwitch)
        content.addView(mealTimeButton)
        content.addView(timetableSwitch)
        content.addView(timetableTimeButton)
        content.addView(schoolNoticeSwitch)
        content.addView(schoolNoticeTimeButton)

        fun updateAvailability() {
            val masterEnabled = masterSwitch.isChecked
            mealSwitch.isEnabled = masterEnabled
            timetableSwitch.isEnabled = masterEnabled
            schoolNoticeSwitch.isEnabled = masterEnabled
            mealTimeButton.isEnabled = masterEnabled && mealSwitch.isChecked
            timetableTimeButton.isEnabled = masterEnabled && timetableSwitch.isChecked
            schoolNoticeTimeButton.isEnabled =
                masterEnabled && schoolNoticeSwitch.isChecked
        }

        masterSwitch.setOnCheckedChangeListener { _, _ -> updateAvailability() }
        mealSwitch.setOnCheckedChangeListener { _, _ -> updateAvailability() }
        timetableSwitch.setOnCheckedChangeListener { _, _ -> updateAvailability() }
        schoolNoticeSwitch.setOnCheckedChangeListener { _, _ -> updateAvailability() }
        mealTimeButton.setOnClickListener {
            showTimeInputDialog(mealTime) { selectedTime ->
                mealTime = selectedTime
                updateNotificationTimeButton(
                    mealTimeButton,
                    R.string.notification_meal_time,
                    selectedTime
                )
            }
        }
        timetableTimeButton.setOnClickListener {
            showTimeInputDialog(timetableTime) { selectedTime ->
                timetableTime = selectedTime
                updateNotificationTimeButton(
                    timetableTimeButton,
                    R.string.notification_timetable_time,
                    selectedTime
                )
            }
        }
        schoolNoticeTimeButton.setOnClickListener {
            showTimeInputDialog(schoolNoticeTime) { selectedTime ->
                schoolNoticeTime = selectedTime
                updateNotificationTimeButton(
                    schoolNoticeTimeButton,
                    R.string.notification_school_notice_time,
                    selectedTime
                )
            }
        }
        updateAvailability()

        val dialog = AlertDialog.Builder(this)
            .setView(ScrollView(this).apply { addView(content) })
            .setNegativeButton(R.string.notification_settings_cancel, null)
            .setPositiveButton(R.string.notification_settings_save) { _, _ ->
                updateNativeNotificationSettings(
                    masterSwitch.isChecked,
                    mealSwitch.isChecked,
                    timetableSwitch.isChecked,
                    schoolNoticeSwitch.isChecked,
                    mealTime,
                    timetableTime,
                    schoolNoticeTime
                )
            }
            .create()
        dialog.setOnShowListener {
            dialog.window?.setBackgroundDrawable(
                roundedBackground(palette.surface, palette.border, 24)
            )
            dialog.getButton(AlertDialog.BUTTON_POSITIVE)?.setTextColor(palette.accent)
            dialog.getButton(AlertDialog.BUTTON_NEGATIVE)?.setTextColor(palette.accent)
        }
        dialog.show()
    }

    private fun createNotificationSwitch(
        labelResId: Int,
        checked: Boolean,
        palette: NativePalette
    ): Switch =
        Switch(this).apply {
            text = getString(labelResId)
            isChecked = checked
            setTextColor(palette.text)
            buttonTintList = ColorStateList(
                arrayOf(
                    intArrayOf(android.R.attr.state_checked),
                    intArrayOf()
                ),
                intArrayOf(palette.accent, palette.muted)
            )
            thumbTintList = ColorStateList(
                arrayOf(
                    intArrayOf(android.R.attr.state_checked),
                    intArrayOf()
                ),
                intArrayOf(palette.accent, palette.muted)
            )
            trackTintList = ColorStateList(
                arrayOf(
                    intArrayOf(android.R.attr.state_checked),
                    intArrayOf()
                ),
                intArrayOf(
                    Color.argb(110, Color.red(palette.accent), Color.green(palette.accent), Color.blue(palette.accent)),
                    palette.border
                )
            )
            setPadding(0, dp(10), 0, dp(10))
        }

    private fun createNotificationTimeButton(
        labelResId: Int,
        time: String,
        palette: NativePalette
    ): Button =
        Button(this).apply {
            isAllCaps = false
            minHeight = 0
            minimumHeight = 0
            setTextColor(palette.text)
            background = roundedBackground(palette.control, palette.border, 16)
            setPadding(dp(12), dp(7), dp(12), dp(7))
            updateNotificationTimeButton(this, labelResId, time)
        }

    private fun updateNotificationTimeButton(button: Button, labelResId: Int, time: String) {
        button.text = getString(
            R.string.notification_time_format,
            getString(labelResId),
            displayTime(time)
        )
    }

    private fun showTimeInputDialog(time: String, onSelected: (String) -> Unit) {
        val palette = nativePalette()
        val timeParts = time.split(":")
        val currentHour = timeParts.getOrNull(0)?.toIntOrNull() ?: 0
        val hour12 = if (currentHour % 12 == 0) 12 else currentHour % 12
        val hourInput = createTimeInput(hour12.toString(), R.string.notification_time_hour_hint, palette)
        val minuteInput =
            createTimeInput(timeParts.getOrNull(1) ?: "00", R.string.notification_time_minute_hint, palette)
        val morningButton = createPeriodButton(R.string.notification_time_am, palette)
        val afternoonButton = createPeriodButton(R.string.notification_time_pm, palette)
        val periodGroup = RadioGroup(this).apply {
            orientation = RadioGroup.HORIZONTAL
            setPadding(0, dp(16), 0, 0)
            addView(
                morningButton,
                RadioGroup.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
            )
            addView(
                afternoonButton,
                RadioGroup.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
            )
            check(if (currentHour < 12) morningButton.id else afternoonButton.id)
        }

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(22), dp(18), dp(22), dp(12))
            addView(createDialogTitle(R.string.notification_time_editor_title, palette))
            addView(
                LinearLayout(this@MainActivity).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER_VERTICAL
                    addView(
                        createLabeledTimeInput(
                            R.string.notification_time_hour,
                            hourInput,
                            palette
                        ),
                        LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
                    )
                    addView(
                        TextView(this@MainActivity).apply {
                            text = ":"
                            textSize = 26f
                            gravity = Gravity.CENTER
                            setTextColor(palette.text)
                        },
                        LinearLayout.LayoutParams(dp(34), ViewGroup.LayoutParams.MATCH_PARENT)
                    )
                    addView(
                        createLabeledTimeInput(
                            R.string.notification_time_minute,
                            minuteInput,
                            palette
                        ),
                        LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
                    )
                }
            )
            addView(periodGroup)
        }

        val dialog = AlertDialog.Builder(this)
            .setView(content)
            .setNegativeButton(R.string.notification_settings_cancel, null)
            .setPositiveButton(R.string.notification_time_confirm, null)
            .create()
        dialog.setOnShowListener {
            dialog.window?.setBackgroundDrawable(
                roundedBackground(palette.surface, palette.border, 24)
            )
            dialog.getButton(AlertDialog.BUTTON_NEGATIVE)?.setTextColor(palette.accent)
            dialog.getButton(AlertDialog.BUTTON_POSITIVE)?.apply {
                setTextColor(palette.accent)
                setOnClickListener {
                    val hourText = hourInput.text.toString().trim()
                    val minuteText = minuteInput.text.toString().trim()
                    if (hourText.isEmpty() || minuteText.isEmpty()) {
                        Toast.makeText(
                            this@MainActivity,
                            R.string.notification_time_required,
                            Toast.LENGTH_SHORT
                        ).show()
                        return@setOnClickListener
                    }

                    val hour = hourText.toIntOrNull()
                    val minute = minuteText.toIntOrNull()
                    if (hour == null || hour !in 1..12 || minute == null || minute !in 0..59) {
                        Toast.makeText(
                            this@MainActivity,
                            R.string.notification_time_invalid,
                            Toast.LENGTH_SHORT
                        ).show()
                        return@setOnClickListener
                    }

                    val hour24 = if (periodGroup.checkedRadioButtonId == morningButton.id) {
                        hour % 12
                    } else {
                        (hour % 12) + 12
                    }
                    onSelected(String.format(Locale.US, "%02d:%02d", hour24, minute))
                    dialog.dismiss()
                }
            }
        }
        dialog.show()
    }

    private fun displayTime(time: String): String {
        val parts = time.split(":")
        val hour = parts.getOrNull(0)?.toIntOrNull() ?: 0
        val minute = parts.getOrNull(1)?.toIntOrNull() ?: 0
        val period = if (hour < 12) {
            getString(R.string.notification_time_am)
        } else {
            getString(R.string.notification_time_pm)
        }
        val hour12 = if (hour % 12 == 0) 12 else hour % 12
        return String.format(Locale.US, "%s %d:%02d", period, hour12, minute)
    }

    private fun createPeriodButton(labelResId: Int, palette: NativePalette): RadioButton =
        RadioButton(this).apply {
            id = View.generateViewId()
            text = getString(labelResId)
            textSize = 15f
            setTextColor(palette.text)
            buttonTintList = ColorStateList(
                arrayOf(
                    intArrayOf(android.R.attr.state_checked),
                    intArrayOf()
                ),
                intArrayOf(palette.accent, palette.muted)
            )
            setPadding(dp(8), dp(8), dp(8), dp(8))
        }

    private fun createDialogTitle(titleResId: Int, palette: NativePalette): TextView =
        TextView(this).apply {
            text = getString(titleResId)
            textSize = 20f
            setTextColor(palette.text)
            setPadding(0, 0, 0, dp(16))
        }

    private fun createLabeledTimeInput(
        labelResId: Int,
        input: EditText,
        palette: NativePalette
    ): LinearLayout =
        LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            addView(
                TextView(this@MainActivity).apply {
                    text = getString(labelResId)
                    textSize = 13f
                    setTextColor(palette.muted)
                    setPadding(dp(2), 0, 0, dp(7))
                }
            )
            addView(input)
        }

    private fun createTimeInput(
        value: String,
        hintResId: Int,
        palette: NativePalette
    ): EditText =
        EditText(this).apply {
            setText(value)
            hint = getString(hintResId)
            textSize = 22f
            gravity = Gravity.CENTER
            inputType = InputType.TYPE_CLASS_NUMBER
            filters = arrayOf(InputFilter.LengthFilter(2))
            setSelectAllOnFocus(true)
            setTextColor(palette.text)
            setHintTextColor(palette.muted)
            background = roundedBackground(palette.control, palette.border, 14)
            setPadding(dp(10), 0, dp(10), 0)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(56)
            )
        }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()

    private fun applyNativeThemeToCard() {
        if (!::notificationSettingsIcon.isInitialized) return
        notificationSettingsIcon.setColorFilter(nativePalette().accent)
    }

    private fun nativePalette(): NativePalette {
        val dark = when (getSavedTheme()) {
            "dark" -> true
            "light" -> false
            else -> (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
        }
        return if (dark) {
            NativePalette(
                surface = "#242424".toColorInt(),
                control = "#303030".toColorInt(),
                text = "#F5F7FA".toColorInt(),
                border = "#383838".toColorInt(),
                muted = "#70757D".toColorInt(),
                accent = "#0B73FF".toColorInt()
            )
        } else {
            NativePalette(
                surface = Color.WHITE,
                control = "#F5F7FB".toColorInt(),
                text = "#20242A".toColorInt(),
                border = "#E4E8EF".toColorInt(),
                muted = "#B8C0CC".toColorInt(),
                accent = "#0B73FF".toColorInt()
            )
        }
    }

    private fun roundedBackground(fillColor: Int, strokeColor: Int, radiusDp: Int) =
        GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(radiusDp).toFloat()
            setColor(fillColor)
            setStroke(dp(1), strokeColor)
        }

    private data class NativePalette(
        val surface: Int,
        val control: Int,
        val text: Int,
        val border: Int,
        val muted: Int,
        val accent: Int
    )

    fun setNativeNotificationsEnabled(enabled: Boolean) {
        notificationScheduler.setMasterEnabled(enabled)
        if (!enabled) {
            notificationScheduler.cancelAllLocalNotifications()
            unsubscribeFromLegacyMealTopic()
            updateWebNotificationState(false)
            Toast.makeText(this, R.string.notification_disabled, Toast.LENGTH_SHORT).show()
            return
        }

        requestNotificationPermissionAndSchedule(showConfirmation = true)
    }

    fun updateNativeNotificationSettings(
        enabled: Boolean,
        mealEnabled: Boolean,
        timetableEnabled: Boolean,
        schoolNoticeEnabled: Boolean,
        mealTime: String?,
        timetableTime: String?,
        schoolNoticeTime: String?
    ) {
        notificationScheduler.updateSettings(
            enabled,
            mealEnabled,
            timetableEnabled,
            schoolNoticeEnabled,
            mealTime,
            timetableTime,
            schoolNoticeTime
        )
        if (!enabled) {
            setNativeNotificationsEnabled(false)
            return
        }

        requestNotificationPermissionAndSchedule(showConfirmation = false)
    }

    fun setNativeNotificationCategoryEnabled(categoryKey: String, enabled: Boolean) {
        val category = NativeNotificationCategory.fromKey(categoryKey) ?: return
        notificationScheduler.setCategoryEnabled(category, enabled)
        if (!enabled) {
            notificationScheduler.cancelCategory(category, cancelVisible = true)
            if (category == NativeNotificationCategory.MEAL) {
                unsubscribeFromLegacyMealTopic()
            }
            return
        }

        if (notificationScheduler.settings().enabled) {
            requestNotificationPermissionAndSchedule(showConfirmation = false)
        }
    }

    fun setNativeNotificationCategoryTime(categoryKey: String, time: String?): Boolean {
        val category = NativeNotificationCategory.fromKey(categoryKey) ?: return false
        val saved = notificationScheduler.setCategoryTime(category, time)
        if (
            saved &&
            notificationScheduler.settings().enabled &&
            notificationScheduler.canPostNotifications()
        ) {
            notificationScheduler.scheduleSelectedNotifications()
        }
        return saved
    }

    fun getNativeNotificationSettings(): String = notificationScheduler.settingsJson()

    fun cacheTodayMealNotificationContent(renderedTitle: String?, body: String?) {
        notificationScheduler.cacheTodayMealContent(renderedTitle, body)
    }

    fun cacheTodayTimetableNotificationContent(renderedTitle: String?, body: String?) {
        notificationScheduler.cacheTodayTimetableContent(renderedTitle, body)
    }

    fun enableBarcodeScanMode() {
        if (barcodeScanModeEnabled) return
        barcodeScanModeEnabled = true
        val attributes = window.attributes
        attributes.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_FULL
        window.attributes = attributes
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    fun disableBarcodeScanMode() {
        if (!barcodeScanModeEnabled) return
        barcodeScanModeEnabled = false
        val attributes = window.attributes
        attributes.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
        window.attributes = attributes
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    private fun requestNotificationPermissionAndSchedule(showConfirmation: Boolean) {
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            return
        }

        notificationScheduler.scheduleSelectedNotifications()
        syncLegacyMealTopicSubscription()
        updateWebNotificationState(true)
        if (showConfirmation) {
            Toast.makeText(this, R.string.notification_enabled, Toast.LENGTH_SHORT).show()
        }
    }

    private fun syncLegacyMealTopicSubscription() {
        val settings = notificationScheduler.settings()
        if (settings.enabled && settings.mealEnabled && notificationScheduler.canPostNotifications()) {
            FirebaseMessaging.getInstance().subscribeToTopic(NOTIFICATION_TOPIC)
                .addOnCompleteListener { task ->
                    if (!task.isSuccessful) {
                        Log.w(TAG, "Failed to subscribe to legacy meal FCM topic", task.exception)
                    }
                }
        } else {
            unsubscribeFromLegacyMealTopic()
        }
    }

    private fun unsubscribeFromLegacyMealTopic() {
        FirebaseMessaging.getInstance().unsubscribeFromTopic(NOTIFICATION_TOPIC)
            .addOnCompleteListener { task ->
                if (!task.isSuccessful) {
                    Log.w(TAG, "Failed to unsubscribe from legacy meal FCM topic", task.exception)
                }
            }
    }

    private fun updateWebNotificationState(enabled: Boolean) {
        runOnUiThread {
            webView.evaluateJavascript(
                "window.setNativeNotificationEnabled && window.setNativeNotificationEnabled($enabled)",
                null
            )
        }
    }

    fun saveTheme(theme: String?) {
        if (theme == "dark" || theme == "light") {
            preferences.edit { putString(KEY_THEME, theme) }
            runOnUiThread { applyNativeThemeToCard() }
        }
    }

    fun getSavedTheme(): String = preferences.getString(KEY_THEME, "") ?: ""

    private fun applySavedThemeToPage() {
        val theme = getSavedTheme()
        if (theme != "dark" && theme != "light") {
            return
        }

        val script = """
            (function(){
              var theme='$theme';
              try{localStorage.setItem('theme',theme);}catch(e){}
              document.documentElement.classList.toggle('dark-theme',theme==='dark');
              document.documentElement.classList.toggle('light-theme',theme==='light');
              if(document.body){
                document.body.classList.toggle('dark-theme',theme==='dark');
                document.body.classList.toggle('light-theme',theme==='light');
              }
            })();
        """.trimIndent()

        runOnUiThread {
            webView.evaluateJavascript(script, null)
        }
    }

    private fun syncNativeThemeFromPage() {
        webView.evaluateJavascript(
            "(function(){try{return localStorage.getItem('theme') || '';}catch(e){return '';}})();"
        ) { value ->
            val theme = value?.trim()?.trim('"')
            if (theme == "dark" || theme == "light") {
                saveTheme(theme)
            } else {
                applyNativeThemeToCard()
            }
        }
    }

    private fun collectFileChooserResults(data: Intent): Array<Uri> {
        val result = mutableListOf<Uri>()
        data.clipData?.let { clipData ->
            for (index in 0 until clipData.itemCount) {
                clipData.getItemAt(index)?.uri?.let { uri ->
                    persistReadPermission(uri)
                    result += uri
                }
            }
        }

        data.data?.let { uri ->
            persistReadPermission(uri)
            result += uri
        }

        return result.distinct().toTypedArray()
    }

    private fun persistReadPermission(uri: Uri) {
        try {
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
        } catch (error: SecurityException) {
            Log.d(TAG, "Read permission is transient for $uri")
        } catch (error: IllegalArgumentException) {
            Log.d(TAG, "URI does not support persistable permission: $uri")
        }
    }

    override fun onDestroy() {
        disableBarcodeScanMode()
        fileChooserCallback?.onReceiveValue(null)
        fileChooserCallback = null
        if (::webView.isInitialized) {
            webView.destroy()
        }
        super.onDestroy()
    }

    override fun onPause() {
        disableBarcodeScanMode()
        super.onPause()
    }

    companion object {
        const val NOTIFICATION_TOPIC = "meal"

        private const val APP_URL = "https://ghaslunch1.web.app/"
        private const val PREFS_NAME = "ghas_lunch_preferences"
        private const val KEY_THEME = "theme"
        private const val TAG = "GHASLunch"
        private const val NOTIFICATION_ICON_TOUCH_SIZE_DP = 44
        private const val NOTIFICATION_ICON_PADDING_DP = 11
        private const val NOTIFICATION_ICON_TOP_MARGIN_DP = 14
        private const val NOTIFICATION_ICON_SIDE_MARGIN_DP = 14
    }
}
