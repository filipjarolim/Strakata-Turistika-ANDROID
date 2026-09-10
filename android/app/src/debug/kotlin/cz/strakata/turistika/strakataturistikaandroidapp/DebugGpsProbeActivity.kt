package cz.strakata.turistika.strakataturistikaandroidapp

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/// Debug-only helper so we can start/stop GPS from adb without login UI.
class DebugGpsProbeActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val stop = intent.getBooleanExtra("stop", false)
        val service = Intent(this, GPSTrackingService::class.java).apply {
            action = if (stop) {
                GPSTrackingService.ACTION_STOP_TRACKING
            } else {
                GPSTrackingService.ACTION_START_TRACKING
            }
            if (!stop) {
                putExtra(GPSTrackingService.EXTRA_RESET_PERSIST, true)
            }
        }
        if (stop) {
            startService(service)
        } else {
            startForegroundService(service)
        }
        finish()
    }
}
