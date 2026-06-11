package com.forge.app.ui.screens

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.unit.dp
import com.forge.app.packaging.ForgeOrientation
import com.forge.app.viewmodel.ForgeUiState
import com.forge.app.viewmodel.ForgeViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CustomizeScreen(
    viewModel: ForgeViewModel,
    uiState: ForgeUiState,
    onBack: () -> Unit,
    onForge: () -> Unit
) {
    val iconLauncher = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) viewModel.setIconFromUri(uri)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Customize your app") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                val icon = uiState.iconBitmap
                if (icon != null) {
                    Image(
                        bitmap = icon.asImageBitmap(),
                        contentDescription = "App icon",
                        modifier = Modifier
                            .size(72.dp)
                            .clip(RoundedCornerShape(16.dp))
                            .clickable { iconLauncher.launch("image/*") }
                    )
                }
                Spacer(modifier = Modifier.padding(start = 12.dp))
                Column {
                    Text("App icon", style = MaterialTheme.typography.titleSmall)
                    Text(
                        "Tap to choose a picture, or keep the generated one",
                        style = MaterialTheme.typography.bodySmall
                    )
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            OutlinedTextField(
                value = uiState.appName,
                onValueChange = viewModel::setAppName,
                label = { Text("App name") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(modifier = Modifier.height(24.dp))

            Text("Orientation", style = MaterialTheme.typography.titleSmall)
            Spacer(modifier = Modifier.height(8.dp))
            OrientationPicker(
                selected = uiState.orientation,
                onSelect = viewModel::setOrientation
            )

            Spacer(modifier = Modifier.height(32.dp))

            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("Ready to forge?", style = MaterialTheme.typography.titleSmall)
                    Text(
                        "Forge will build \"${uiState.appName.ifBlank { "your app" }}\" as its own " +
                            "installable APK, right on this device.",
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.padding(top = 4.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            Button(
                onClick = onForge,
                enabled = uiState.appName.isNotBlank(),
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("🔨 Forge APK")
            }
        }
    }
}

private val ORIENTATIONS = listOf(
    ForgeOrientation.UNSPECIFIED to "Auto",
    ForgeOrientation.PORTRAIT to "Portrait",
    ForgeOrientation.LANDSCAPE to "Landscape",
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun OrientationPicker(selected: ForgeOrientation, onSelect: (ForgeOrientation) -> Unit) {
    SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
        ORIENTATIONS.forEachIndexed { index, (value, label) ->
            SegmentedButton(
                selected = selected == value,
                onClick = { onSelect(value) },
                shape = SegmentedButtonDefaults.itemShape(index, ORIENTATIONS.size)
            ) {
                Text(label)
            }
        }
    }
}
