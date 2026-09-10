package cz.strakata.turistika.strakataturistikaandroidapp

import android.app.*
import android.content.Intent
import android.content.pm.ServiceInfo
import android.location.Location
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import com.google.android.gms.location.*
import java.io.File

class GPSTrackingService : Service() {
    private val TAG = "GPSTrackingService"
    private val binder = LocalBinder()
    
    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationCallback: LocationCallback
    private lateinit var notificationManager: NotificationManager
    
    private var isTracking = false
    private var lastLocation: Location? = null
    private var trackingStartTime: Long = 0
    // Adaptive request parameters (can be updated at runtime)
    private var intervalMs: Long = 12000L
    private var fastestIntervalMs: Long = 8000L
    private var maxWaitTimeMs: Long = 24000L
    private var smallestDisplacementM: Float = 10.0f
    private var priority: Int = Priority.PRIORITY_HIGH_ACCURACY
    private var statsTitle: String = "Sledování trasy"
    private var statsText: String = "Klepnutím se vrátíte do aplikace"
    private var persistCount: Int = 0
    private val persistBuf = StringBuilder()
    private var lastNotificationAtElapsed: Long = 0L
    
    inner class LocalBinder : Binder() {
        fun getService(): GPSTrackingService = this@GPSTrackingService
    }
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "GPSTrackingService onCreate")
        
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        
        createLocationCallback()
        createNotificationChannel()
    }
    
    private fun createLocationCallback() {
        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                locationResult.lastLocation?.let { location ->
                    Log.d(TAG, "Location update: ${location.latitude}, ${location.longitude}")
                    lastLocation = location
                    persistLocation(location)
                    maybeUpdateNotification()
                    
                    // Send location to Flutter via method channel
                    sendLocationToFlutter(location)
                }
            }
        }
    }
    
    private fun sendLocationToFlutter(location: Location) {
        try {
            // Send location to Flutter via MainActivity
            MainActivity.sendLocationToFlutter(location)
            Log.d(TAG, "Location sent to Flutter: ${location.latitude}, ${location.longitude}")
        } catch (e: Exception) {
            Log.w(TAG, "Error sending location to Flutter: ${e.message}")
        }
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "GPSTrackingService onStartCommand")
        
        when (intent?.action) {
            ACTION_START_TRACKING -> {
                val reset = intent.getBooleanExtra(EXTRA_RESET_PERSIST, true)
                startTracking(resetPersist = reset)
            }
            ACTION_STOP_TRACKING -> stopTracking()
            ACTION_UPDATE_STATS -> {
                statsTitle = intent.getStringExtra(EXTRA_STATS_TITLE) ?: statsTitle
                statsText = intent.getStringExtra(EXTRA_STATS_TEXT) ?: statsText
                if (isTracking) {
                    updateNotification()
                }
            }
            ACTION_UPDATE_SETTINGS -> {
                // Update settings from intent extras
                intent.extras?.let { extras ->
                    if (extras.containsKey(EXTRA_INTERVAL_MS)) {
                        intervalMs = extras.getLong(EXTRA_INTERVAL_MS, intervalMs)
                    }
                    if (extras.containsKey(EXTRA_FASTEST_MS)) {
                        fastestIntervalMs = extras.getLong(EXTRA_FASTEST_MS, fastestIntervalMs)
                    }
                    if (extras.containsKey(EXTRA_MAX_WAIT_MS)) {
                        maxWaitTimeMs = extras.getLong(EXTRA_MAX_WAIT_MS, maxWaitTimeMs)
                    }
                    if (extras.containsKey(EXTRA_SMALLEST_DISPLACEMENT)) {
                        smallestDisplacementM = extras.getFloat(EXTRA_SMALLEST_DISPLACEMENT, smallestDisplacementM)
                    }
                    if (extras.containsKey(EXTRA_PRIORITY)) {
                        priority = extras.getInt(EXTRA_PRIORITY, priority)
                    }
                    Log.d(TAG, "Updating location settings: interval=${intervalMs}ms fastest=${fastestIntervalMs}ms maxWait=${maxWaitTimeMs}ms smallestDisp=${smallestDisplacementM}m priority=${priority}")
                    if (isTracking) {
                        reRequestLocationUpdates()
                    }
                }
            }
            else -> {
                // START_STICKY restart after process death — continue without wiping the track.
                if (isActiveFlagSet()) {
                    Log.d(TAG, "Sticky restart — resuming GPS tracking")
                    startTracking(resetPersist = false)
                }
            }
        }
        
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder {
        return binder
    }
    
    fun startTracking(resetPersist: Boolean = true) {
        if (isTracking) return
        
        Log.d(TAG, "Starting GPS tracking (resetPersist=$resetPersist)")
        isTracking = true
        trackingStartTime = System.currentTimeMillis()
        // Mark running so Flutter can avoid duplicating notifications
        MainActivity.isGpsServiceRunning = true
        writeActiveFlag()
        if (resetPersist) {
            resetPersistFile()
            persistCount = 0
            persistBuf.clear()
        }
        
        try {
            val notification = createNotification()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                ServiceCompat.startForeground(
                    this,
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            lastNotificationAtElapsed = SystemClock.elapsedRealtime()
            
            // Request location updates
            requestLocationUpdates()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start foreground GPS tracking service", e)
            isTracking = false
            MainActivity.isGpsServiceRunning = false
            clearActiveFlag()
            stopSelf()
        }
    }
    
    fun stopTracking() {
        if (!isTracking) return
        
        Log.d(TAG, "Stopping GPS tracking")
        isTracking = false
        MainActivity.isGpsServiceRunning = false
        clearActiveFlag()
        flushPersist()
        
        // Stop location updates
        try {
            fusedLocationClient.removeLocationUpdates(locationCallback)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to remove location updates on stop", e)
        }
        
        try {
            ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to stop foreground", e)
        }
        stopSelf()
    }
    
    private fun requestLocationUpdates() {
        val locationRequest = LocationRequest.Builder(priority, intervalMs)
            .setMinUpdateIntervalMillis(fastestIntervalMs)
            .setMaxUpdateDelayMillis(maxWaitTimeMs)
            .setMinUpdateDistanceMeters(smallestDisplacementM)
            .setWaitForAccurateLocation(false)
            .build()
        
        try {
            fusedLocationClient.requestLocationUpdates(
                locationRequest,
                locationCallback,
                mainLooper
            )
            Log.d(TAG, "Location updates requested interval=${intervalMs}ms priority=$priority disp=${smallestDisplacementM}m")
        } catch (e: SecurityException) {
            Log.e(TAG, "Security exception requesting location updates", e)
        }
    }

    private fun reRequestLocationUpdates() {
        try {
            fusedLocationClient.removeLocationUpdates(locationCallback)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to remove previous updates before re-requesting", e)
        }
        requestLocationUpdates()
    }
    
    private fun persistFile(): File = File(filesDir, PERSIST_FILE)

    private fun resetPersistFile() {
        try {
            persistFile().writeText("")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to reset persist file", e)
        }
    }

    private fun persistLocation(location: Location) {
        try {
            persistBuf.append(
                "${location.latitude},${location.longitude},${location.time},${location.accuracy},${location.speed},${location.altitude}\n"
            )
            persistCount++
            // Flush immediately on each point so zero points are lost on unexpected process death
            flushPersist()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to persist location", e)
        }
    }

    private fun flushPersist() {
        if (persistBuf.isEmpty()) return
        try {
            persistFile().appendText(persistBuf.toString())
            persistBuf.clear()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to flush persist buffer", e)
        }
    }

    private fun activeFlagFile(): File = File(filesDir, ACTIVE_FLAG_FILE)

    private fun writeActiveFlag() {
        try {
            activeFlagFile().writeText("1")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to write active flag", e)
        }
    }

    private fun clearActiveFlag() {
        try {
            activeFlagFile().delete()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to clear active flag", e)
        }
    }

    private fun isActiveFlagSet(): Boolean = activeFlagFile().exists()

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "GPS Tracking",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Shows GPS tracking status"
            setShowBadge(false)
            enableLights(false)
            enableVibration(false)
        }
        notificationManager.createNotificationChannel(channel)
    }
    
    private fun createNotification(): Notification {
        // Do NOT use FLAG_ACTIVITY_CLEAR_TASK: it wipes the task and restarts the app,
        // which drops in-memory GPS track state in Flutter while the user only meant to return to the app.
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(statsTitle)
            .setContentText(statsText)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .build()
    }
    
    private fun maybeUpdateNotification() {
        if (!isTracking) return
        val now = SystemClock.elapsedRealtime()
        if (now - lastNotificationAtElapsed < 15_000L) return
        lastNotificationAtElapsed = now
        notificationManager.notify(NOTIFICATION_ID, createNotification())
    }

    private fun updateNotification() {
        if (isTracking) {
            lastNotificationAtElapsed = SystemClock.elapsedRealtime()
            notificationManager.notify(NOTIFICATION_ID, createNotification())
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "GPSTrackingService onDestroy")
        
        MainActivity.isGpsServiceRunning = false
        flushPersist()
        if (isTracking) {
            try {
                fusedLocationClient.removeLocationUpdates(locationCallback)
            } catch (e: Exception) {
                Log.w(TAG, "Failed to remove location updates on destroy", e)
            }
        }
    }
    
    companion object {
        private const val CHANNEL_ID = "gps_tracking_channel"
        private const val NOTIFICATION_ID = 1001
        const val ACTION_START_TRACKING = "START_TRACKING"
        const val ACTION_STOP_TRACKING = "STOP_TRACKING"
        const val ACTION_UPDATE_SETTINGS = "UPDATE_SETTINGS"
        const val ACTION_UPDATE_STATS = "UPDATE_STATS"
        const val EXTRA_INTERVAL_MS = "interval_ms"
        const val EXTRA_FASTEST_MS = "fastest_ms"
        const val EXTRA_MAX_WAIT_MS = "max_wait_ms"
        const val EXTRA_SMALLEST_DISPLACEMENT = "smallest_displacement_m"
        const val EXTRA_PRIORITY = "priority"
        const val EXTRA_STATS_TITLE = "stats_title"
        const val EXTRA_STATS_TEXT = "stats_text"
        const val EXTRA_RESET_PERSIST = "reset_persist"
        const val PERSIST_FILE = "gps_track_persist.jsonl"
        const val ACTIVE_FLAG_FILE = "gps_tracking_active.flag"
    }
} 