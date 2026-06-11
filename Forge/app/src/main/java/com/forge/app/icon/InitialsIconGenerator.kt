package com.forge.app.icon

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import kotlin.math.abs

/** Generates a default launcher icon from an app name's initials when the user doesn't pick one. */
object InitialsIconGenerator {

    private val PALETTE = listOf(
        0xFFFF7A1A.toInt(), // Forge orange
        0xFF7C4DFF.toInt(), // Forge purple
        0xFF00B8D4.toInt(),
        0xFF43A047.toInt(),
        0xFFE53935.toInt(),
        0xFF3949AB.toInt(),
        0xFFFB8C00.toInt(),
        0xFF00897B.toInt(),
    )

    fun generate(name: String, sizePx: Int = 192): Bitmap {
        val initials = initialsFor(name)
        val color = PALETTE[abs(name.hashCode()) % PALETTE.size]

        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color }
        canvas.drawRect(0f, 0f, sizePx.toFloat(), sizePx.toFloat(), bgPaint)

        val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = Color.WHITE
            textSize = sizePx * 0.45f
            typeface = Typeface.create(Typeface.DEFAULT_BOLD, Typeface.BOLD)
            textAlign = Paint.Align.CENTER
        }
        val metrics = textPaint.fontMetrics
        val textY = sizePx / 2f - (metrics.ascent + metrics.descent) / 2f
        canvas.drawText(initials, sizePx / 2f, textY, textPaint)

        return bitmap
    }

    private fun initialsFor(name: String): String {
        val words = name.trim().split(Regex("\\s+")).filter { it.isNotBlank() }
        return when {
            words.isEmpty() -> "?"
            words.size == 1 -> words[0].take(2).uppercase()
            else -> (words[0].take(1) + words[1].take(1)).uppercase()
        }
    }
}
