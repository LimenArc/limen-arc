package com.limenArc.terminal

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.DrawerValue
import androidx.compose.material3.ModalNavigationDrawer
import androidx.compose.material3.rememberDrawerState
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.limenArc.terminal.ui.components.AppDestination
import com.limenArc.terminal.ui.components.AppDrawer
import com.limenArc.terminal.ui.screens.FileBrowserScreen
import com.limenArc.terminal.ui.screens.PackagesScreen
import com.limenArc.terminal.ui.screens.SettingsScreen
import com.limenArc.terminal.ui.screens.TerminalScreen
import com.limenArc.terminal.ui.theme.LimenArcTerminalTheme
import com.limenArc.terminal.viewmodel.FileBrowserViewModel
import com.limenArc.terminal.viewmodel.PackagesViewModel
import com.limenArc.terminal.viewmodel.TerminalViewModel
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            LimenArcTerminalTheme {
                AppRoot()
            }
        }
    }
}

@Composable
private fun AppRoot() {
    val navController: NavHostController = rememberNavController()
    val drawerState = rememberDrawerState(DrawerValue.Closed)
    val scope = rememberCoroutineScope()

    val navBackStack by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStack?.destination?.route ?: AppDestination.Terminal.route

    // Shared ViewModels hoisted to root so they survive navigation
    val terminalVm: TerminalViewModel = viewModel()
    val fileBrowserVm: FileBrowserViewModel = viewModel()
    val packagesVm: PackagesViewModel = viewModel()

    ModalNavigationDrawer(
        drawerState = drawerState,
        drawerContent = {
            AppDrawer(
                currentRoute = currentRoute,
                onNavigate = { dest ->
                    navController.navigate(dest.route) {
                        launchSingleTop = true
                        restoreState = true
                        popUpTo(AppDestination.Terminal.route) { saveState = true }
                    }
                },
                onClose = { scope.launch { drawerState.close() } },
            )
        },
        modifier = Modifier.fillMaxSize(),
    ) {
        NavHost(
            navController = navController,
            startDestination = AppDestination.Terminal.route,
            modifier = Modifier.fillMaxSize(),
        ) {
            composable(AppDestination.Terminal.route) {
                TerminalScreen(
                    onOpenDrawer = { scope.launch { drawerState.open() } },
                    vm = terminalVm,
                )
            }
            composable(AppDestination.FileBrowser.route) {
                FileBrowserScreen(
                    onOpenDrawer = { scope.launch { drawerState.open() } },
                    vm = fileBrowserVm,
                )
            }
            composable(AppDestination.Packages.route) {
                PackagesScreen(
                    onOpenDrawer = { scope.launch { drawerState.open() } },
                    vm = packagesVm,
                )
            }
            composable(AppDestination.Settings.route) {
                SettingsScreen(
                    onOpenDrawer = { scope.launch { drawerState.open() } },
                )
            }
        }
    }
}
