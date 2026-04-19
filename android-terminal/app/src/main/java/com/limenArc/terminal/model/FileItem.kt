package com.limenArc.terminal.model

import java.io.File

enum class FileType { DIRECTORY, FILE, SYMLINK, EXECUTABLE }

data class FileItem(
    val file: File,
    val name: String = file.name,
    val type: FileType = when {
        file.isDirectory    -> FileType.DIRECTORY
        file.canExecute()   -> FileType.EXECUTABLE
        else                -> FileType.FILE
    },
    val size: Long = if (file.isFile) file.length() else 0L,
    val lastModified: Long = file.lastModified(),
    val isHidden: Boolean = file.isHidden,
)
