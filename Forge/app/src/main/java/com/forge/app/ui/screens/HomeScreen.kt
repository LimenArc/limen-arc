package com.forge.app.ui.screens

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.InsertDriveFile
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.PictureAsPdf
import androidx.compose.material.icons.filled.TextSnippet
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Row
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import com.forge.app.viewmodel.ForgeUiState
import com.forge.app.viewmodel.ForgeViewModel
import com.forge.app.viewmodel.UrlMode

private data class InputOption(
    val title: String,
    val subtitle: String,
    val icon: ImageVector,
    val onClick: () -> Unit,
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(viewModel: ForgeViewModel, uiState: ForgeUiState) {
    var showUrlDialog by remember { mutableStateOf(false) }

    val folderLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocumentTree()) { uri ->
        if (uri != null) viewModel.loadFolder(uri)
    }
    val htmlLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) viewModel.loadHtmlFile(uri)
    }
    val markdownLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) viewModel.loadMarkdown(uri)
    }
    val textLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) viewModel.loadText(uri)
    }
    val pdfLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) viewModel.loadPdf(uri)
    }

    val options = listOf(
        InputOption(
            "A folder of web files",
            "Pick a folder with index.html, CSS, JS, images",
            Icons.Filled.Folder
        ) { folderLauncher.launch(null) },
        InputOption(
            "A single HTML file",
            "Wrap one .html page",
            Icons.Filled.InsertDriveFile
        ) { htmlLauncher.launch(arrayOf("text/html")) },
        InputOption(
            "A website URL",
            "Wrap a live site, or save it for offline use",
            Icons.Filled.Language
        ) { showUrlDialog = true },
        InputOption(
            "A Markdown file",
            "Turn a .md file into a styled page",
            Icons.Filled.Description
        ) { markdownLauncher.launch(arrayOf("text/markdown", "text/x-markdown", "text/plain")) },
        InputOption(
            "Plain text",
            "Wrap a .txt file in a simple reader",
            Icons.Filled.TextSnippet
        ) { textLauncher.launch(arrayOf("text/plain")) },
        InputOption(
            "A PDF",
            "Turn a PDF into a page-by-page viewer",
            Icons.Filled.PictureAsPdf
        ) { pdfLauncher.launch(arrayOf("application/pdf")) },
    )

    Scaffold(
        topBar = { TopAppBar(title = { Text("Forge") }) }
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding)) {
            Text(
                text = "Pick something to turn into an app",
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.padding(16.dp)
            )

            if (uiState.isLoadingContent) {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(16.dp),
                    horizontalArrangement = Arrangement.Center
                ) {
                    CircularProgressIndicator()
                }
            }

            uiState.loadError?.let { error ->
                Text(
                    text = "Couldn't load that: $error",
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
                )
            }

            LazyColumn(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
                items(options) { option ->
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 6.dp)
                            .clickable(enabled = !uiState.isLoadingContent, onClick = option.onClick)
                    ) {
                        ListItem(
                            headlineContent = { Text(option.title) },
                            supportingContent = { Text(option.subtitle) },
                            leadingContent = { Icon(option.icon, contentDescription = null) },
                        )
                    }
                }
                item { Spacer(modifier = Modifier.padding(bottom = 24.dp)) }
            }
        }
    }

    if (showUrlDialog) {
        UrlInputDialog(
            onDismiss = { showUrlDialog = false },
            onConfirm = { url, mode ->
                showUrlDialog = false
                viewModel.loadUrl(url, mode)
            }
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun UrlInputDialog(onDismiss: () -> Unit, onConfirm: (String, UrlMode) -> Unit) {
    var url by remember { mutableStateOf("") }
    var mode by remember { mutableStateOf(UrlMode.ONLINE_WRAPPER) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Add a website") },
        text = {
            Column {
                OutlinedTextField(
                    value = url,
                    onValueChange = { url = it },
                    label = { Text("Website address") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(modifier = Modifier.padding(8.dp))
                SingleChoiceSegmentedButtonRow {
                    SegmentedButton(
                        selected = mode == UrlMode.ONLINE_WRAPPER,
                        onClick = { mode = UrlMode.ONLINE_WRAPPER },
                        shape = SegmentedButtonDefaults.itemShape(0, 2)
                    ) { Text("Online") }
                    SegmentedButton(
                        selected = mode == UrlMode.SNAPSHOT,
                        onClick = { mode = UrlMode.SNAPSHOT },
                        shape = SegmentedButtonDefaults.itemShape(1, 2)
                    ) { Text("Offline copy") }
                }
                Text(
                    text = if (mode == UrlMode.ONLINE_WRAPPER) {
                        "The app will always load this site live (needs internet)."
                    } else {
                        "Forge will try to save a copy so it works offline. Some sites won't work perfectly."
                    },
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.padding(top = 8.dp)
                )
            }
        },
        confirmButton = {
            TextButton(onClick = { if (url.isNotBlank()) onConfirm(url, mode) }) { Text("Continue") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        }
    )
}
