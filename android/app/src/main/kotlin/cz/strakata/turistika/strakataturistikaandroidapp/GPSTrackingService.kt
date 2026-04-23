package cz.strakata.turistika.strakataturistikaandroidapp

import android.app.*
import android.content.Intent
import android.location.Location
import android.location.LocationManager
import android.os.Binder
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.*
import java.util.concurrent.TimeUnit

class GPSTrackingService : Service() {
    private val TAG = "GPSTrackingService"
    private val binder = LocalBinder()
    
    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationCallback: LocationCallback
    private lateinit var wakeLock: PowerManager.WakeLock
    private lateinit var notificationManager: NotificationManager
    
    private var isTracking = false
    private var lastLocation: Location? = null
    private var trackingStartTime: Long = 0
    // Adaptive request parameters (can be updated at runtime)
    private var intervalMs: Long = 4000L
    private var fastestIntervalMs: Long = 2000L
    private var maxWaitTimeMs: Long = 6000L
    private var smallestDisplacementM: Float = 1.0f
    private var priority: Int = Priority.PRIORITY_HIGH_ACCURACY
    
    inner class LocalBinder : Binder() {
        fun getService(): GPSTrackingService = this@GPSTrackingService
    }
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "GPSTrackingService onCreate")
        
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        
        // Create wake lock to keep service running
        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "GPSTrackingService::WakeLock"
        )
        
        createLocationCallback()
        createNotificationChannel()
    }
    
    private fun createLocationCallback() {
        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                locationResult.lastLocation?.let { location ->
                    Log.d(TAG, "Location update: ${location.latitude}, ${location.longitude}")
                    lastLocation = location
                    updateNotification()
                    
                    // Send location to Flutter via method channel
                    sendLocationToFlutter(location)
                }
            }
        }
    }
    
    private fun sendLocationToFlutter(location: Location) {
        // Send location to Flutter via MainActivity
        MainActivity.sendLocationToFlutter(location)
        Log.d(TAG, "Location sent to Flutter: ${location.latitude}, ${location.longitude}")
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "GPSTrackingService onStartCommand")
        
        when (intent?.action) {
            ACTION_START_TRACKING -> startTracking()
            ACTION_STOP_TRACKING -> stopTracking()
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
        }
        
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder {
        return binder
    }
    
    fun startTracking() {
        if (isTracking) return
        
        Log.d(TAG, "Starting GPS tracking")
        isTracking = true
        trackingStartTime = System.currentTimeMillis()
        // Mark running so Flutter can avoid duplicating notifications
        MainActivity.isGpsServiceRunning = true
        
        // Acquire wake lock
        if (!wakeLock.isHeld) {
            wakeLock.acquire(10 * 60 * 1000L) // 10 minutes timeout
        }
        
        // Start foreground service with notification
        startForeground(NOTIFICATION_ID, createNotification())
        
        // Request location updates
        requestLocationUpdates()
    }
    
    fun stopTracking() {
        if (!isTracking) return
        
        Log.d(TAG, "Stopping GPS tracking")
        isTracking = false
        MainActivity.isGpsServiceRunning = false
        
        // Stop location updates
        fusedLocationClient.removeLocationUpdates(locationCallback)
        
        // Release wake lock
        if (wakeLock.isHeld) {
            wakeLock.release()
        }
        
        // Stop foreground service
        stopForeground(true)
        stopSelf()
    }
    
    private fun requestLocationUpdates() {
        val locationRequest = LocationRequest.create().apply {
            interval = intervalMs
            fastestInterval = fastestIntervalMs
            priority = this@GPSTrackingService.priority
            maxWaitTime = maxWaitTimeMs
            smallestDisplacement = smallestDisplacementM
        }
        
        try {
            fusedLocationClient.requestLocationUpdates(
                locationRequest,
                locationCallback,
                mainLooper
            )
            Log.d(TAG, "Location updates requested with high accuracy settings")
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
            .setContentTitle("")
            .setContentText("Klepnutím se vrátíte do aplikace")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .build()
    }
    
    private fun updateNotification() {
        if (isTracking) {
            notificationManager.notify(NOTIFICATION_ID, createNotification())
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "GPSTrackingService onDestroy")
        
        MainActivity.isGpsServiceRunning = false
        if (isTracking) {
            fusedLocationClient.removeLocationUpdates(locationCallback)
        }
        
        if (wakeLock.isHeld) {
            wakeLock.release()
        }
    }
    
    companion object {
        private const val CHANNEL_ID = "gps_tracking_channel"
        private const val NOTIFICATION_ID = 1001
        const val ACTION_START_TRACKING = "START_TRACKING"
        const val ACTION_STOP_TRACKING = "STOP_TRACKING"
        const val ACTION_UPDATE_SETTINGS = "UPDATE_SETTINGS"
        const val EXTRA_INTERVAL_MS = "interval_ms"
        const val EXTRA_FASTEST_MS = "fastest_ms"
        const val EXTRA_MAX_WAIT_MS = "max_wait_ms"
        const val EXTRA_SMALLEST_DISPLACEMENT = "smallest_displacement_m"
        const val EXTRA_PRIORITY = "priority"
    }
} 