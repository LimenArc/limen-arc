package com.limenArc.terminal.terminal

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.withContext
import java.io.File

class CommandExecutor(private var workingDirectory: File = File(System.getProperty("user.home") ?: "/data/data")) {

    var currentDir: File = workingDirectory
        private set

    fun execute(command: String): Flow<String> = flow {
        val trimmed = command.trim()
        if (trimmed.isEmpty()) return@flow

        // Handle built-in shell commands without spawning a process
        when {
            trimmed == "clear" || trimmed == "cls" -> {
                emit("\u001b[2J\u001b[H")  // ANSI clear screen
                return@flow
            }
            trimmed.startsWith("cd ") -> {
                val target = trimmed.removePrefix("cd ").trim()
                val newDir = resolveDir(target)
                if (newDir != null && newDir.isDirectory) {
                    currentDir = newDir
                    emit("")
                } else {
                    emit("cd: no such file or directory: $target")
                }
                return@flow
            }
            trimmed == "cd" || trimmed == "cd ~" -> {
                currentDir = File(System.getProperty("user.home") ?: currentDir.absolutePath)
                emit("")
                return@flow
            }
            trimmed == "pwd" -> {
                emit(currentDir.absolutePath)
                return@flow
            }
        }

        // Execute via shell
        runCatching {
            val process = ProcessBuilder("sh", "-c", trimmed)
                .directory(currentDir)
                .redirectErrorStream(true)
                .start()

            val reader = process.inputStream.bufferedReader()
            var line: String?
            while (reader.readLine().also { line = it } != null) {
                emit(line!!)
            }

            val exit = process.waitFor()
            if (exit != 0) emit("\u001b[31m[exit $exit]\u001b[0m")
        }.onFailure { e ->
            emit("\u001b[31mError: ${e.message}\u001b[0m")
        }
    }.flowOn(Dispatchers.IO)

    private fun resolveDir(path: String): File? {
        if (path.isEmpty() || path == "~") return File(System.getProperty("user.home") ?: return null)
        val f = if (path.startsWith("/")) File(path) else File(currentDir, path)
        return f.canonicalFile
    }

    suspend fun prompt(): String = withContext(Dispatchers.IO) {
        val home = System.getProperty("user.home") ?: ""
        val displayPath = currentDir.absolutePath.replace(home, "~")
        "\u001b[32m$ \u001b[0m\u001b[34m$displayPath\u001b[0m \u001b[32m❯\u001b[0m "
    }
}
