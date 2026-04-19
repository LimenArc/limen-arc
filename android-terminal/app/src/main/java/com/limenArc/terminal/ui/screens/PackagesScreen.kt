package com.limenArc.terminal.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.limenArc.terminal.model.Package
import com.limenArc.terminal.model.PackageStatus
import com.limenArc.terminal.ui.theme.*
import com.limenArc.terminal.viewmodel.PackagesViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PackagesScreen(
    onOpenDrawer: () -> Unit,
    vm: PackagesViewModel = viewModel(),
) {
    val query by vm.searchQuery.collectAsStateWithLifecycle()
    val isRefreshing by vm.isRefreshing.collectAsStateWithLifecycle()
    val installing by vm.installing.collectAsStateWithLifecycle()
    val packages = vm.filtered

    Scaffold(
        containerColor = TerminalBackground,
        topBar = {
            TopAppBar(
                title = { Text("Packages", color = TerminalMagenta) },
                navigationIcon = {
                    IconButton(onClick = onOpenDrawer) {
                        Icon(Icons.Default.Menu, "Menu", tint = TerminalText)
                    }
                },
                actions = {
                    if (isRefreshing) {
                        CircularProgressIndicator(modifier = Modifier.size(20.dp).padding(end = 8.dp), color = TerminalGreen, strokeWidth = 2.dp)
                    } else {
                        IconButton(onClick = { vm.refresh() }) {
                            Icon(Icons.Default.Refresh, "Refresh", tint = TerminalText)
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = TerminalSurface),
            )
        },
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding)) {
            // Search bar
            OutlinedTextField(
                value = query,
                onValueChange = vm::search,
                modifier = Modifier.fillMaxWidth().padding(8.dp),
                placeholder = { Text("Search packages…", color = TerminalTextDim, fontSize = 13.sp, fontFamily = FontFamily.Monospace) },
                leadingIcon = { Icon(Icons.Default.Search, null, tint = TerminalTextDim) },
                trailingIcon = {
                    if (query.isNotEmpty()) IconButton(onClick = { vm.search("") }) {
                        Icon(Icons.Default.Clear, null, tint = TerminalTextDim)
                    }
                },
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = TerminalMagenta,
                    unfocusedBorderColor = TerminalBorder,
                    focusedTextColor = TerminalText,
                    unfocusedTextColor = TerminalText,
                    cursorColor = TerminalMagenta,
                ),
                singleLine = true,
                shape = RoundedCornerShape(8.dp),
            )

            // Stats row
            PackageStats(packages)

            HorizontalDivider(color = TerminalBorder, thickness = 0.5.dp)

            LazyColumn(modifier = Modifier.fillMaxSize()) {
                items(packages, key = { it.name }) { pkg ->
                    PackageRow(
                        pkg = pkg,
                        isInstalling = pkg.name in installing,
                        onInstall = { vm.install(pkg) },
                        onUninstall = { vm.uninstall(pkg) },
                    )
                    HorizontalDivider(color = TerminalBorder, thickness = 0.5.dp)
                }
            }
        }
    }
}

@Composable
private fun PackageStats(packages: List<Package>) {
    val installed = packages.count { it.status == PackageStatus.INSTALLED }
    val upgradable = packages.count { it.status == PackageStatus.UPGRADABLE }
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        StatChip("${packages.size} total", TerminalTextDim)
        StatChip("$installed installed", TerminalGreen)
        if (upgradable > 0) StatChip("$upgradable upgradable", TerminalYellow)
    }
}

@Composable
private fun StatChip(label: String, color: androidx.compose.ui.graphics.Color) {
    Surface(
        color = TerminalSurfaceAlt,
        shape = RoundedCornerShape(4.dp),
    ) {
        Text(label, color = color, fontSize = 11.sp, fontFamily = FontFamily.Monospace, modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp))
    }
}

@Composable
private fun PackageRow(
    pkg: Package,
    isInstalling: Boolean,
    onInstall: () -> Unit,
    onUninstall: () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(pkg.name, color = TerminalText, fontSize = 14.sp, fontWeight = FontWeight.Medium, fontFamily = FontFamily.Monospace)
                Spacer(Modifier.width(8.dp))
                StatusBadge(pkg.status)
            }
            Text(pkg.description, color = TerminalTextDim, fontSize = 12.sp, maxLines = 1)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(pkg.version, color = TerminalCyan, fontSize = 11.sp, fontFamily = FontFamily.Monospace)
                if (pkg.size.isNotEmpty()) Text(pkg.size, color = TerminalTextDim, fontSize = 11.sp, fontFamily = FontFamily.Monospace)
                Text(pkg.category, color = TerminalTextDim, fontSize = 11.sp)
            }
        }

        when {
            isInstalling -> CircularProgressIndicator(modifier = Modifier.size(24.dp), color = TerminalGreen, strokeWidth = 2.dp)
            pkg.status == PackageStatus.INSTALLED -> IconButton(onClick = onUninstall, modifier = Modifier.size(36.dp)) {
                Icon(Icons.Default.Delete, "Uninstall", tint = TerminalRed, modifier = Modifier.size(20.dp))
            }
            pkg.status == PackageStatus.UPGRADABLE -> IconButton(onClick = onInstall, modifier = Modifier.size(36.dp)) {
                Icon(Icons.Default.Upgrade, "Upgrade", tint = TerminalYellow, modifier = Modifier.size(20.dp))
            }
            else -> IconButton(onClick = onInstall, modifier = Modifier.size(36.dp)) {
                Icon(Icons.Default.Download, "Install", tint = TerminalGreen, modifier = Modifier.size(20.dp))
            }
        }
    }
}

@Composable
private fun StatusBadge(status: PackageStatus) {
    val (label, color) = when (status) {
        PackageStatus.INSTALLED  -> "installed" to TerminalGreen
        PackageStatus.AVAILABLE  -> "available" to TerminalTextDim
        PackageStatus.UPGRADABLE -> "upgradable" to TerminalYellow
    }
    Surface(color = color.copy(alpha = 0.15f), shape = RoundedCornerShape(3.dp)) {
        Text(label, color = color, fontSize = 10.sp, fontFamily = FontFamily.Monospace, modifier = Modifier.padding(horizontal = 5.dp, vertical = 2.dp))
    }
}
