package com.aura.aura_player

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.Rect
import android.graphics.RectF
import android.view.KeyEvent
import android.widget.RemoteViews
import java.io.File

class AuraWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val title = prefs.getString("title", null) ?: "Aura"
        val artist = prefs.getString("artist", null) ?: "Tap to open"
        val playing = prefs.getBoolean("playing", false)
        val artPath = prefs.getString("art", null)
        val art = loadArt(artPath)

        for (id in ids) {
            val v = RemoteViews(context.packageName, R.layout.aura_widget)
            v.setTextViewText(R.id.w_title, title)
            v.setTextViewText(R.id.w_artist, artist)
            v.setImageViewResource(
                R.id.w_play,
                if (playing) R.drawable.ic_w_pause else R.drawable.ic_w_play
            )
            if (art != null) v.setImageViewBitmap(R.id.w_art, art)
            else v.setImageViewResource(R.id.w_art, R.drawable.w_art_placeholder)

            v.setOnClickPendingIntent(R.id.w_prev, media(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS, 1))
            v.setOnClickPendingIntent(R.id.w_play, media(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE, 2))
            v.setOnClickPendingIntent(R.id.w_next, media(context, KeyEvent.KEYCODE_MEDIA_NEXT, 3))

            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launch != null) {
                val open = PendingIntent.getActivity(
                    context, 0, launch,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )
                v.setOnClickPendingIntent(R.id.w_art, open)
                v.setOnClickPendingIntent(R.id.w_texts, open)
            }
            manager.updateAppWidget(id, v)
        }
    }

    private fun media(ctx: Context, keyCode: Int, req: Int): PendingIntent {
        val i = Intent(Intent.ACTION_MEDIA_BUTTON)
            .setComponent(ComponentName(ctx, "com.ryanheise.audioservice.MediaButtonReceiver"))
        i.putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
        return PendingIntent.getBroadcast(
            ctx, req, i,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
    }

    private fun loadArt(path: String?): Bitmap? {
        if (path.isNullOrEmpty()) return null
        val f = File(path)
        if (!f.exists()) return null
        return try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(path, bounds)
            var sample = 1
            while (bounds.outWidth / sample > 440) sample *= 2
            val src = BitmapFactory.decodeFile(
                path, BitmapFactory.Options().apply { inSampleSize = sample }
            ) ?: return null

            // centre-crop to a rounded square
            val size = 220
            val out = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(out)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            canvas.drawRoundRect(RectF(0f, 0f, size.toFloat(), size.toFloat()), 48f, 48f, paint)
            paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
            val side = minOf(src.width, src.height)
            val l = (src.width - side) / 2
            val t = (src.height - side) / 2
            canvas.drawBitmap(src, Rect(l, t, l + side, t + side), Rect(0, 0, size, size), paint)
            out
        } catch (e: Exception) {
            null
        }
    }
}
