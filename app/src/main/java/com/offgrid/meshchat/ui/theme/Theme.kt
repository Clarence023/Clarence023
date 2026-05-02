package com.offgrid.meshchat.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val OffGridColors = darkColorScheme(
    primary = Color(0xFF4DD0E1),
    secondary = Color(0xFF80CBC4),
    tertiary = Color(0xFFB39DDB),
    background = Color(0xFF05080F),
    surface = Color(0xFF0B1220)
)

@Composable
fun OffGridTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = OffGridColors,
        content = content
    )
}
