package com.forge.app.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Error
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.forge.app.packaging.ForgeStage

private val STAGES = listOf(
    ForgeStage.Injecting::class to "Injecting your content",
    ForgeStage.Patching::class to "Patching app name & package",
    ForgeStage.PatchingIcon::class to "Applying your icon",
    ForgeStage.Aligning::class to "Aligning the package",
    ForgeStage.Signing::class to "Signing the APK",
    ForgeStage.WritingOutput::class to "Saving to Downloads/Forge",
)

@Composable
fun ForgingScreen(
    stage: ForgeStage?,
    onDone: (ForgeStage.Done) -> Unit,
    onRetry: () -> Unit,
) {
    LaunchedEffect(stage) {
        if (stage is ForgeStage.Done) onDone(stage)
    }

    Scaffold { padding ->
        Column(
            modifier = Modifier.fillMaxSize().padding(padding).padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            when (stage) {
                is ForgeStage.Error -> ErrorContent(stage, onRetry)
                is ForgeStage.Done -> CircularProgressIndicator() // brief flash before navigation
                else -> ProgressContent(stage)
            }
        }
    }
}

@Composable
private fun ProgressContent(stage: ForgeStage?) {
    val currentIndex = STAGES.indexOfFirst { it.first.isInstance(stage) }.let { if (it < 0) 0 else it }
    val progress = (currentIndex + 1f) / STAGES.size

    Text("Forging your app…", style = MaterialTheme.typography.headlineSmall)
    androidx.compose.foundation.layout.Spacer(modifier = Modifier.padding(top = 16.dp))
    LinearProgressIndicator(progress = { progress }, modifier = Modifier.fillMaxWidth())
    androidx.compose.foundation.layout.Spacer(modifier = Modifier.padding(top = 16.dp))
    STAGES.forEachIndexed { index, (_, label) ->
        val style = if (index == currentIndex) {
            MaterialTheme.typography.bodyLarge
        } else {
            MaterialTheme.typography.bodyMedium
        }
        val color = if (index <= currentIndex) {
            MaterialTheme.colorScheme.onSurface
        } else {
            MaterialTheme.colorScheme.onSurfaceVariant
        }
        Text(
            text = if (index < currentIndex) "✅ $label" else if (index == currentIndex) "⏳ $label" else "• $label",
            style = style,
            color = color,
            modifier = Modifier.padding(vertical = 4.dp)
        )
    }
}

@Composable
private fun ErrorContent(error: ForgeStage.Error, onRetry: () -> Unit) {
    Icon(
        Icons.Filled.Error,
        contentDescription = null,
        tint = MaterialTheme.colorScheme.error,
        modifier = Modifier.padding(bottom = 16.dp)
    )
    Text("Something went wrong", style = MaterialTheme.typography.headlineSmall)
    Text(
        text = error.message,
        style = MaterialTheme.typography.bodyMedium,
        modifier = Modifier.padding(top = 8.dp, bottom = 24.dp)
    )
    Button(onClick = onRetry) { Text("Try again") }
}
