package com.pocketstrike.pocketstrike

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.Display
import java.io.File
import java.io.FileOutputStream

/**
 * Foreground service that owns the live MediaProjection pipeline.
 *
 * Responsibilities:
 *  - Start/stop screen capture into a VirtualDisplay fed by a 1-frame
 *    ImageReader so the service keeps producing fresh frames.
 *  - Write JPEG snapshots into the app's external Pictures dir so the
 *    Flutter side can open and display them via MethodChannel.
 *  - All entry points are driven from [MainActivity]'s channel by posting
 *    start/stop intents with the result code + token from the
 *    `MediaProjectionManager.createScreenCaptureIntent()` user grant.
 */
class ScreenControlService : Service() {

    companion object {
        const val ACTION_START = "com.pocketstrike.pocketstrike.ACTION_SCREEN_START"
        const val ACTION_STOP = "com.pocketstrike.pocketstrike.ACTION_SCREEN_STOP"

        const val EXTRA_RESULT_CODE = "extra_result_code"
        const val EXTRA_TOKEN = "extra_token"

        private const val CHANNEL_ID = "screen_control_channel"
        private const val NOTIF_ID = 42

        /** Latest frame file path; exposed to the channel from the Flutter side. */
        @Volatile
        var lastSnapshotFileGlobal: String? = null
            private set

        fun startIntent(context: Context, resultCode: Int, resultData: Intent): Intent {
            val intent = Intent(context, ScreenControlService::class.java)
            intent.action = ACTION_START
            intent.putExtra(EXTRA_RESULT_CODE, resultCode)
            intent.putExtra(EXTRA_TOKEN, resultData)
            return intent
        }

        fun stopIntent(context: Context): Intent =
            Intent(context, ScreenControlService::class.java).apply {
                action = ACTION_STOP
            }
    }

    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null

    private val mainHandler: Handler = Handler(Looper.getMainLooper())

    @Volatile
    private var workerThread: Thread? = null

    private fun spawnWorkerThread(): Thread = Thread({
        while (!Thread.currentThread().isInterrupted) {
            val reader = imageReader ?: break
            val image: Image? = try {
                reader.acquireLatestImage()
            } catch (e: Exception) {
                null
            }
            if (image != null) {
                try {
                    val file = writeJpegSnapshot(image)
                    if (file != null) {
                        lastSnapshotFileGlobal = file
                        lastSnapshotFile = file
                    }
                } finally {
                    image.close()
                }
            }
            // ~12 FPS refresh so the UI can poll the latest frame cheaply.
            try {
                Thread.sleep(80L)
            } catch (_: InterruptedException) {
                return@Thread
            }
        }
    }, "PocketStrikeScreenWorker")

    @Volatile
    var lastSnapshotFile: String? = null
        private set

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        startForegroundScreenNotif()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, 0)
                val resultData = intent.getParcelableExtra<Intent>(EXTRA_TOKEN)
                if (resultData != null) startProjection(resultCode, resultData) else stopSelf()
            }
            ACTION_STOP -> stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun startProjection(resultCode: Int, resultData: Intent) {
        releasePipeline()

        val projectionManager =
            getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        mediaProjection = projectionManager.getMediaProjection(resultCode, resultData)

        val displayManager = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        val display = displayManager.getDisplay(Display.DEFAULT_DISPLAY)
        val metrics = resources.displayMetrics
        display.getRealMetrics(metrics)

        val reader = ImageReader.newInstance(
            metrics.widthPixels,
            metrics.heightPixels,
            PixelFormat.RGBA_8888,
            2
        )
        imageReader = reader

        virtualDisplay = mediaProjection?.createVirtualDisplay(
            "PocketStrikeScreenDisplay",
            metrics.widthPixels,
            metrics.heightPixels,
            metrics.densityDpi,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_PUBLIC,
            reader.surface,
            null,
            mainHandler
        )

        // Start the worker thread AFTER the virtual display is up so we don't
        // read from a null imageReader.
        workerThread = spawnWorkerThread().also { it.start() }
    }

    private fun releasePipeline() {
        workerThread?.interrupt()
        workerThread = null
        virtualDisplay?.release()
        virtualDisplay = null
        imageReader?.close()
        imageReader = null
        mediaProjection?.stop()
        mediaProjection = null
    }

    private fun writeJpegSnapshot(image: Image): String? {
        return try {
            val bitmap = imageToBitmap(image)
            val outDir = getExternalFilesDir(Environment.DIRECTORY_PICTURES)
                ?: File(filesDir, "Pictures")
            if (!outDir.exists()) outDir.mkdirs()
            val out = File(outDir, "live_frame_${System.currentTimeMillis()}.jpg")
            FileOutputStream(out).use { fos ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 92, fos)
            }
            bitmap.recycle()
            outDir.listFiles(java.io.FileFilter { f -> f.name.startsWith("live_frame_") })
                ?.filter { it.absolutePath != out.absolutePath }
                ?.forEach { it.delete() }
            out.absolutePath
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    /** Copies an [Image]'s first plane into a [Bitmap] (works for RGBA_8888). */
    private fun imageToBitmap(image: Image): Bitmap {
        val plane = image.planes[0]
        val buffer = plane.buffer
        val pixelStride = plane.pixelStride
        val rowStride = plane.rowStride
        val width = image.width
        val height = image.height

        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        if (pixelStride == 4 && rowStride == width * 4) {
            bitmap.copyPixelsFromBuffer(buffer)
            return bitmap
        }
        // Fallback: manual stride copy into an int[]-free pixel array.
        val pixels = IntArray(width * height)
        for (row in 0 until height) {
            var offset = row * rowStride
            for (col in 0 until width) {
                val r = buffer.get(offset).toInt() and 0xFF
                val g = buffer.get(offset + 1).toInt() and 0xFF
                val b = buffer.get(offset + 2).toInt() and 0xFF
                val a = buffer.get(offset + 3).toInt() and 0xFF
                pixels[row * width + col] = (a shl 24) or (r shl 16) or (g shl 8) or b
                offset += pixelStride
            }
        }
        bitmap.setPixels(pixels, 0, width, 0, 0, width, height)
        return bitmap
    }

    override fun onDestroy() {
        super.onDestroy()
        releasePipeline()
    }

    private fun startForegroundScreenNotif() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Screen Control Service",
                NotificationManager.IMPORTANCE_LOW
            )
            nm.createNotificationChannel(channel)
        }
        val openIntent = Intent(this, MainActivity::class.java)
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        else
            PendingIntent.FLAG_UPDATE_CURRENT
        val pending = PendingIntent.getActivity(this, 0, openIntent, flags)
        val builder = Notification.Builder(this)
            .setSmallIcon(android.R.drawable.ic_lock_silent_mode_off)
            .setContentTitle("PocketStrike Screen Control Active")
            .setContentText("Live screen pipeline is running. Stop it in-app when done.")
            .setOngoing(true)
            .setContentIntent(pending)
            .setAutoCancel(true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            builder.setChannelId(CHANNEL_ID)
        }
        startForeground(NOTIF_ID, builder.build())
    }
}
