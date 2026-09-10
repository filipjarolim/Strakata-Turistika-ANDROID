package cz.strakata.turistika.strakataturistikaandroidapp

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "gps_tracking_channel"
    private val EVENT_CHANNEL = "gps_location_events"
    private val ICON_CHANNEL = "app_icon_channel"
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var iconChannel: MethodChannel? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // super already registers plugins via GeneratedPluginRegistrant
        super.configureFlutterEngine(flutterEngine)
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
        iconChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ICON_CHANNEL)
        
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startGPSTracking" -> {
                    val resetPersist = (call.arguments as? Map<*, *>)?.get("resetPersist") as? Boolean ?: true
                    startGPSTracking(resetPersist)
                    result.success(true)
                }
                "stopGPSTracking" -> {
                    stopGPSTracking()
                    result.success(true)
                }
                "updateGPSSettings" -> {
                    val args = call.arguments as? Map<*, *>
                    updateGPSSettings(
                        intervalMs = (args?.get("intervalMs") as? Number)?.toLong() ?: 4000L,
                        fastestIntervalMs = (args?.get("fastestIntervalMs") as? Number)?.toLong() ?: 2000L,
                        maxWaitTimeMs = (args?.get("maxWaitTimeMs") as? Number)?.toLong() ?: 6000L,
                        smallestDisplacementM = (args?.get("smallestDisplacementM") as? Number)?.toFloat() ?: 1.0f,
                        priority = (args?.get("priority") as? Number)?.toInt() ?: com.google.android.gms.location.Priority.PRIORITY_HIGH_ACCURACY
                    )
                    result.success(true)
                }
                "isGPSTracking" -> {
                    result.success(isGPSTracking())
                }
                "updateTrackingStats" -> {
                    val args = call.arguments as? Map<*, *>
                    updateTrackingStats(
                        (args?.get("title") as? String) ?: "Sledování trasy",
                        (args?.get("text") as? String) ?: "Klepnutím se vrátíte do aplikace"
                    )
                    result.success(true)
                }
                "readPersistedTrack" -> {
                    result.success(readPersistedTrack())
                }
                "clearPersistedTrack" -> {
                    val file = File(filesDir, GPSTrackingService.PERSIST_FILE)
                    if (file.exists()) file.delete()
                    val flag = File(filesDir, GPSTrackingService.ACTIVE_FLAG_FILE)
                    if (flag.exists()) flag.delete()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        iconChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "setIcon" -> {
                    val args = call.arguments as? Map<*, *>
                    val alias = args?.get("androidAlias") as? String
                    if (alias.isNullOrBlank()) {
                        result.error("bad_args", "Missing androidAlias", null)
                        return@setMethodCallHandler
                    }
                    try {
                        setLauncherAlias(alias)
                        result.success("ok")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Failed to switch icon", e)
                        result.error("icon_switch_failed", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        // Set up event channel for location updates
        eventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                // Store the event sink for sending location updates
                locationEventSink = events
            }
            
            override fun onCancel(arguments: Any?) {
                locationEventSink = null
            }
        })
    }

    private fun setLauncherAlias(enabledSuffix: String) {
        val pm = packageManager
        val main = ComponentName(this, MainActivity::class.java)
        val autumn = ComponentName(this, "$packageName.MainActivityAutumn")
        // Legacy alias from older builds — keep disabled so flutter run stays healthy.
        val legacyClassic = ComponentName(this, "$packageName.MainActivityClassic")
        val useAutumn = enabledSuffix == "MainActivityAutumn"
        val debuggable = (applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0

        try {
            pm.setComponentEnabledSetting(
                legacyClassic,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
        } catch (_: Exception) {
            // Alias may not exist after clean install.
        }

        // Debug: never disable MainActivity — Flutter tooling launches that class.
        if (debuggable) {
            pm.setComponentEnabledSetting(
                main,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )
            pm.setComponentEnabledSetting(
                autumn,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
            Log.i("MainActivity", "Debug build: launcher stays on MainActivity (requested=$enabledSuffix)")
            return
        }

        // Release: classic = MainActivity, autumn = activity-alias icon.
        pm.setComponentEnabledSetting(
            main,
            if (useAutumn) PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            else PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP
        )
        pm.setComponentEnabledSetting(
            autumn,
            if (useAutumn) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP
        )
    }
    
    private fun startGPSTracking(resetPersist: Boolean) {
        Log.d("MainActivity", "Starting GPS tracking service (resetPersist=$resetPersist)")
        val intent = Intent(this, GPSTrackingService::class.java).apply {
            action = GPSTrackingService.ACTION_START_TRACKING
            putExtra(GPSTrackingService.EXTRA_RESET_PERSIST, resetPersist)
        }
        startForegroundService(intent)
    }
    
    private fun stopGPSTracking() {
        Log.d("MainActivity", "Stopping GPS tracking service")
        val intent = Intent(this, GPSTrackingService::class.java).apply {
            action = GPSTrackingService.ACTION_STOP_TRACKING
        }
        startService(intent)
    }
    
    private fun updateTrackingStats(title: String, text: String) {
        val intent = Intent(this, GPSTrackingService::class.java).apply {
            action = GPSTrackingService.ACTION_UPDATE_STATS
            putExtra(GPSTrackingService.EXTRA_STATS_TITLE, title)
            putExtra(GPSTrackingService.EXTRA_STATS_TEXT, text)
        }
        startService(intent)
    }

    private fun isGPSTracking(): Boolean {
        if (isGpsServiceRunning) return true
        return try {
            File(filesDir, GPSTrackingService.ACTIVE_FLAG_FILE).exists()
        } catch (_: Exception) {
            false
        }
    }

    private fun readPersistedTrack(): List<Map<String, Any>> {
        val file = File(filesDir, GPSTrackingService.PERSIST_FILE)
        if (!file.exists()) return emptyList()
        return try {
            file.readLines().mapNotNull { line ->
                val p = line.split(",")
                if (p.size < 3) return@mapNotNull null
                mapOf(
                    "latitude" to (p[0].toDoubleOrNull() ?: return@mapNotNull null),
                    "longitude" to (p[1].toDoubleOrNull() ?: return@mapNotNull null),
                    "timestamp" to (p[2].toLongOrNull() ?: 0L),
                    "accuracy" to (p.getOrNull(3)?.toDoubleOrNull() ?: 0.0),
                    "speed" to (p.getOrNull(4)?.toDoubleOrNull() ?: 0.0),
                    "altitude" to (p.getOrNull(5)?.toDoubleOrNull() ?: 0.0),
                )
            }
        } catch (e: Exception) {
            Log.w("MainActivity", "Failed to read persisted track", e)
            emptyList()
        }
    }
    
    private fun updateGPSSettings(
        intervalMs: Long,
        fastestIntervalMs: Long,
        maxWaitTimeMs: Long,
        smallestDisplacementM: Float,
        priority: Int
    ) {
        val intent = Intent(this, GPSTrackingService::class.java).apply {
            action = GPSTrackingService.ACTION_UPDATE_SETTINGS
            putExtra(GPSTrackingService.EXTRA_INTERVAL_MS, intervalMs)
            putExtra(GPSTrackingService.EXTRA_FASTEST_MS, fastestIntervalMs)
            putExtra(GPSTrackingService.EXTRA_MAX_WAIT_MS, maxWaitTimeMs)
            putExtra(GPSTrackingService.EXTRA_SMALLEST_DISPLACEMENT, smallestDisplacementM)
            putExtra(GPSTrackingService.EXTRA_PRIORITY, priority)
        }
        startService(intent)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        iconChannel?.setMethodCallHandler(null)
        iconChannel = null
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        locationEventSink = null
    }

    override fun onDestroy() {
        super.onDestroy()
        locationEventSink = null
    }
    
    companion object {
        var locationEventSink: EventChannel.EventSink? = null
        @JvmStatic var isGpsServiceRunning: Boolean = false
        
        fun sendLocationToFlutter(location: Location) {
            try {
                locationEventSink?.success(mapOf(
                    "latitude" to location.latitude,
                    "longitude" to location.longitude,
                    "accuracy" to location.accuracy,
                    "speed" to location.speed,
                    "altitude" to location.altitude,
                    "timestamp" to location.time
                ))
            } catch (e: Exception) {
                Log.w("MainActivity", "Failed to deliver location to Flutter event channel: ${e.message}")
            }
        }
    }
}
