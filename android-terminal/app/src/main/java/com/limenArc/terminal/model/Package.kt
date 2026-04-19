package com.limenArc.terminal.model

enum class PackageStatus { INSTALLED, AVAILABLE, UPGRADABLE }

data class Package(
    val name: String,
    val version: String,
    val description: String,
    val status: PackageStatus = PackageStatus.AVAILABLE,
    val size: String = "",
    val category: String = "utilities",
)
