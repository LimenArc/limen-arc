package com.forge.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.forge.app.packaging.ForgeStage
import com.forge.app.ui.screens.CustomizeScreen
import com.forge.app.ui.screens.ForgingScreen
import com.forge.app.ui.screens.HomeScreen
import com.forge.app.ui.screens.PreviewScreen
import com.forge.app.ui.screens.SuccessScreen
import com.forge.app.ui.theme.ForgeTheme
import com.forge.app.viewmodel.ForgeViewModel

private object Routes {
    const val HOME = "home"
    const val PREVIEW = "preview"
    const val CUSTOMIZE = "customize"
    const val FORGING = "forging"
    const val SUCCESS = "success"
}

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            ForgeTheme {
                ForgeApp()
            }
        }
    }
}

@Composable
fun ForgeApp(viewModel: ForgeViewModel = viewModel()) {
    val navController = rememberNavController()
    val uiState by viewModel.uiState.collectAsState()

    // When new content finishes loading, jump to the preview screen.
    LaunchedEffect(uiState.content) {
        if (uiState.content != null && navController.currentDestination?.route == Routes.HOME) {
            navController.navigate(Routes.PREVIEW)
        }
    }

    NavHost(navController = navController, startDestination = Routes.HOME) {
        composable(Routes.HOME) {
            HomeScreen(viewModel = viewModel, uiState = uiState)
        }
        composable(Routes.PREVIEW) {
            val content = uiState.content
            if (content != null) {
                PreviewScreen(
                    content = content,
                    onBack = {
                        viewModel.resetAll()
                        navController.popBackStack()
                    },
                    onContinue = { navController.navigate(Routes.CUSTOMIZE) }
                )
            }
        }
        composable(Routes.CUSTOMIZE) {
            CustomizeScreen(
                viewModel = viewModel,
                uiState = uiState,
                onBack = { navController.popBackStack() },
                onForge = {
                    viewModel.startForging()
                    navController.navigate(Routes.FORGING)
                }
            )
        }
        composable(Routes.FORGING) {
            ForgingScreen(
                stage = uiState.forgeStage,
                onDone = { done: ForgeStage.Done ->
                    navController.navigate(Routes.SUCCESS) {
                        popUpTo(Routes.HOME) { inclusive = false }
                    }
                },
                onRetry = {
                    viewModel.resetForging()
                    navController.popBackStack(Routes.CUSTOMIZE, inclusive = false)
                }
            )
        }
        composable(Routes.SUCCESS) {
            val done = uiState.forgeStage as? ForgeStage.Done
            if (done != null) {
                SuccessScreen(
                    done = done,
                    onForgeAnother = {
                        viewModel.resetAll()
                        navController.navigate(Routes.HOME) {
                            popUpTo(Routes.HOME) { inclusive = true }
                        }
                    }
                )
            }
        }
    }
}
