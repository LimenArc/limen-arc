package com.forge.app.ui.screens

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.forge.app.output.InstallLauncher
import com.forge.app.packaging.ForgeStage

@Composable
fun SuccessScreen(done: ForgeStage.Done, onForgeAnother: () -> Unit) {
    val context = LocalContext.current
    var canInstall by remember { mutableStateOf(InstallLauncher.canRequestInstalls(context)) }

    val settingsLauncher = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) {
        canInstall = InstallLauncher.canRequestInstalls(context)
    }

    Scaffold { padding ->
        Column(
            modifier = Modifier.fillMaxSize().padding(padding).padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text("🎉", style = MaterialTheme.typography.displayLarge)
            Spacer(modifier = Modifier.height(8.dp))
            Text("\"${done.displayName}\" is ready!", style = MaterialTheme.typography.headlineSmall)
            Text(
                "Saved to Downloads/Forge/${done.displayName}.apk",
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.padding(top = 4.dp, bottom = 24.dp)
            )

            if (!canInstall) {
                Card(modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp)) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text("One more step", style = MaterialTheme.typography.titleSmall)
                        Text(
                            "To install apps Forge creates, allow Forge to install unknown apps. " +
                                "This is a normal Android safety check.",
                            style = MaterialTheme.typography.bodySmall,
                            modifier = Modifier.padding(top = 4.dp, bottom = 8.dp)
                        )
                        Button(onClick = { settingsLauncher.launch(InstallLauncher.unknownAppsSettingsIntent(context)) }) {
                            Text("Allow installs")
                        }
                    }
                }
            }

            Button(
                onClick = { context.startActivity(InstallLauncher.installIntent(context, done.outputUri)) },
                enabled = canInstall,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("Install")
            }
            Spacer(modifier = Modifier.height(8.dp))
            OutlinedButton(
                onClick = { context.startActivity(InstallLauncher.shareIntent(context, done.outputUri)) },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("Share")
            }
            Spacer(modifier = Modifier.height(16.dp))
            TextButton(onClick = onForgeAnother) {
                Text("Forge another app")
            }
        }
    }
}
