package com.limenArc.terminal.ui.screens

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.limenArc.terminal.model.FileItem
import com.limenArc.terminal.model.FileType
import com.limenArc.terminal.ui.theme.*
import com.limenArc.terminal.viewmodel.FileBrowserViewModel
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FileBrowserScreen(
    onOpenDrawer: () -> Unit,
    vm: FileBrowserViewModel = viewModel(),
) {
    val currentPath by vm.currentPath.collectAsStateWithLifecycle()
    val files by vm.files.collectAsStateWithLifecycle()
    val showHidden by vm.showHidden.collectAsStateWithLifecycle()
    val isLoading by vm.isLoading.collectAsStateWithLifecycle()
    val error by vm.error.collectAsStateWithLifecycle()

    BackHandler { vm.navigateUp() }

    Scaffold(
        containerColor = TerminalBackground,
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text("File Browser", color = TerminalBlue, fontSize = 16.sp)
                        Text(
                            currentPath.absolutePath,
                            color = TerminalTextDim,
                            fontSize = 11.sp,
                            fontFamily = FontFamily.Monospace,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onOpenDrawer) {
                        Icon(Icons.Default.Menu, "Menu", tint = TerminalText)
                    }
                },
                actions = {
                    IconButton(onClick = { vm.navigateUp() }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "Up", tint = TerminalText)
                    }
                    IconButton(onClick = { vm.toggleHidden() }) {
                        Icon(
                            if (showHidden) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                            "Toggle hidden",
                            tint = if (showHidden) TerminalGreen else TerminalTextDim,
                        )
                    }
                    IconButton(onClick = { vm.refresh() }) {
                        Icon(Icons.Default.Refresh, "Refresh", tint = TerminalText)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = TerminalSurface),
            )
        },
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            when {
                isLoading -> CircularProgressIndicator(
                    modifier = Modifier.align(Alignment.Center),
                    color = TerminalGreen,
                )
                error != null -> ErrorView(error!!, modifier = Modifier.align(Alignment.Center))
                files.isEmpty() -> Text(
                    "No files found",
                    color = TerminalTextDim,
                    modifier = Modifier.align(Alignment.Center),
                )
                else -> FileList(files = files, onNavigate = { item ->
                    if (item.type == FileType.DIRECTORY) vm.navigateTo(item.file)
                }, formatSize = vm::formatSize)
            }
        }
    }
}

@Composable
private fun FileList(
    files: List<FileItem>,
    onNavigate: (FileItem) -> Unit,
    formatSize: (Long) -> String,
) {
    LazyColumn(modifier = Modifier.fillMaxSize()) {
        items(files, key = { it.file.absolutePath }) { item ->
            FileRow(item = item, onClick = { onNavigate(item) }, formatSize = formatSize)
            HorizontalDivider(color = TerminalBorder, thickness = 0.5.dp)
        }
    }
}

@Composable
private fun FileRow(
    item: FileItem,
    onClick: () -> Unit,
    formatSize: (Long) -> String,
) {
    val dateFormat = remember { SimpleDateFormat("MMM dd HH:mm", Locale.getDefault()) }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = when (item.type) {
                FileType.DIRECTORY   -> Icons.Default.Folder
                FileType.EXECUTABLE  -> Icons.Default.Terminal
                FileType.SYMLINK     -> Icons.Default.Link
                FileType.FILE        -> fileIcon(item.name)
            },
            contentDescription = null,
            tint = when (item.type) {
                FileType.DIRECTORY   -> TerminalYellow
                FileType.EXECUTABLE  -> TerminalGreen
                FileType.SYMLINK     -> TerminalCyan
                FileType.FILE        -> TerminalTextDim
            },
            modifier = Modifier.size(22.dp),
        )

        Spacer(Modifier.width(12.dp))

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = item.name,
                color = if (item.isHidden) TerminalTextDim else TerminalText,
                fontSize = 14.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Row {
                Text(
                    text = dateFormat.format(Date(item.lastModified)),
                    color = TerminalTextDim,
                    fontSize = 11.sp,
                    fontFamily = FontFamily.Monospace,
                )
                if (item.type != FileType.DIRECTORY) {
                    Text("  ${formatSize(item.size)}", color = TerminalTextDim, fontSize = 11.sp, fontFamily = FontFamily.Monospace)
                }
            }
        }

        if (item.type == FileType.DIRECTORY) {
            Icon(Icons.Default.ChevronRight, null, tint = TerminalTextDim, modifier = Modifier.size(18.dp))
        }
    }
}

@Composable
private fun ErrorView(message: String, modifier: Modifier = Modifier) {
    Column(modifier = modifier.padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Icon(Icons.Default.ErrorOutline, null, tint = TerminalRed, modifier = Modifier.size(48.dp))
        Spacer(Modifier.height(8.dp))
        Text(message, color = TerminalRed, fontSize = 13.sp, fontFamily = FontFamily.Monospace)
    }
}

private fun fileIcon(name: String) = when (name.substringAfterLast('.').lowercase()) {
    "kt", "java", "py", "js", "ts", "go", "rs", "c", "cpp", "h" -> Icons.Default.Code
    "txt", "md", "rst"  -> Icons.Default.Article
    "json", "xml", "yml", "yaml", "toml" -> Icons.Default.DataObject
    "zip", "tar", "gz", "bz2", "xz", "7z" -> Icons.Default.Archive
    "png", "jpg", "jpeg", "gif", "webp", "svg" -> Icons.Default.Image
    "mp3", "ogg", "wav", "flac", "aac" -> Icons.Default.AudioFile
    "mp4", "mkv", "webm", "avi", "mov" -> Icons.Default.VideoFile
    "pdf" -> Icons.Default.PictureAsPdf
    "apk" -> Icons.Default.Android
    "sh", "bash", "zsh" -> Icons.Default.Terminal
    else -> Icons.Default.InsertDriveFile
}
