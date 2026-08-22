package cz.strakata.turistika.strakataturistikaandroidapp

import android.content.Intent
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
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // super already registers plugins via GeneratedPluginRegistrant
        super.configureFlutterEngine(flutterEngine)
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
        
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startGPSTracking" -> {
                    startGPSTracking()
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
                "readPersistedTrack" -> {
                    result.success(readPersistedTrack())
                }
                "clearPersistedTrack" -> {
                    val file = File(filesDir, GPSTrackingService.PERSIST_FILE)
                    if (file.exists()) file.delete()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
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
    
    private fun startGPSTracking() {
        Log.d("MainActivity", "Starting GPS tracking service")
        val intent = Intent(this, GPSTrackingService::class.java).apply {
            action = GPSTrackingService.ACTION_START_TRACKING
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
    
    private fun isGPSTracking(): Boolean {
        return isGpsServiceRunning
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
    
    companion object {
        var locationEventSink: EventChannel.EventSink? = null
        @JvmStatic var isGpsServiceRunning: Boolean = false
        
        fun sendLocationToFlutter(location: Location) {
            locationEventSink?.success(mapOf(
                "latitude" to location.latitude,
                "longitude" to location.longitude,
                "accuracy" to location.accuracy,
                "speed" to location.speed,
                "altitude" to location.altitude,
                "timestamp" to location.time
            ))
        }
    }
}
