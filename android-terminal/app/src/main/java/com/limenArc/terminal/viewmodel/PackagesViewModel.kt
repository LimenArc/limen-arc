package com.limenArc.terminal.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.limenArc.terminal.model.Package
import com.limenArc.terminal.model.PackageStatus
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class PackagesViewModel : ViewModel() {

    private val _packages = MutableStateFlow(samplePackages())
    val packages: StateFlow<List<Package>> = _packages.asStateFlow()

    private val _searchQuery = MutableStateFlow("")
    val searchQuery: StateFlow<String> = _searchQuery.asStateFlow()

    private val _isRefreshing = MutableStateFlow(false)
    val isRefreshing: StateFlow<Boolean> = _isRefreshing.asStateFlow()

    private val _installing = MutableStateFlow<Set<String>>(emptySet())
    val installing: StateFlow<Set<String>> = _installing.asStateFlow()

    val filtered: List<Package>
        get() {
            val q = _searchQuery.value.trim().lowercase()
            return if (q.isEmpty()) _packages.value
            else _packages.value.filter { q in it.name.lowercase() || q in it.description.lowercase() }
        }

    fun search(query: String) { _searchQuery.value = query }

    fun install(pkg: Package) {
        viewModelScope.launch {
            _installing.value = _installing.value + pkg.name
            delay(2000) // simulate network + install
            _packages.value = _packages.value.map {
                if (it.name == pkg.name) it.copy(status = PackageStatus.INSTALLED) else it
            }
            _installing.value = _installing.value - pkg.name
        }
    }

    fun uninstall(pkg: Package) {
        viewModelScope.launch {
            _installing.value = _installing.value + pkg.name
            delay(1500)
            _packages.value = _packages.value.map {
                if (it.name == pkg.name) it.copy(status = PackageStatus.AVAILABLE) else it
            }
            _installing.value = _installing.value - pkg.name
        }
    }

    fun refresh() {
        viewModelScope.launch {
            _isRefreshing.value = true
            delay(1500)
            _isRefreshing.value = false
        }
    }

    private fun samplePackages() = listOf(
        Package("bash",       "5.2.15", "GNU Bourne Again shell",              PackageStatus.INSTALLED, "2.1 MB", "shells"),
        Package("python",     "3.12.0", "Interactive high-level language",     PackageStatus.INSTALLED, "18 MB",  "interpreters"),
        Package("git",        "2.44.0", "Fast, scalable distributed VCS",      PackageStatus.INSTALLED, "12 MB",  "vcs"),
        Package("curl",       "8.7.1",  "Command line tool for URLs",          PackageStatus.INSTALLED, "1.2 MB", "net"),
        Package("wget",       "1.21.4", "Network file retriever",              PackageStatus.AVAILABLE, "900 KB", "net"),
        Package("vim",        "9.1.0",  "Vi IMproved text editor",             PackageStatus.AVAILABLE, "3.5 MB", "editors"),
        Package("nano",       "7.2",    "Small friendly text editor",          PackageStatus.INSTALLED, "700 KB", "editors"),
        Package("nodejs",     "20.14.0","Server-side JavaScript runtime",      PackageStatus.AVAILABLE, "52 MB",  "interpreters"),
        Package("htop",       "3.3.0",  "Interactive process viewer",          PackageStatus.INSTALLED, "300 KB", "utils"),
        Package("tmux",       "3.4",    "Terminal multiplexer",                PackageStatus.AVAILABLE, "600 KB", "utils"),
        Package("ssh",        "9.7p1",  "OpenSSH client",                     PackageStatus.INSTALLED, "1.8 MB", "net"),
        Package("nmap",       "7.95",   "Network exploration and security",    PackageStatus.AVAILABLE, "4.2 MB", "net"),
        Package("ffmpeg",     "6.1.1",  "Audio/video conversion tool",         PackageStatus.AVAILABLE, "32 MB",  "multimedia"),
        Package("zip",        "3.0",    "Compression and file packaging",      PackageStatus.INSTALLED, "250 KB", "utils"),
        Package("unzip",      "6.0",    "Extraction utility for .zip files",   PackageStatus.INSTALLED, "200 KB", "utils"),
        Package("rsync",      "3.3.0",  "Fast remote file sync",              PackageStatus.AVAILABLE, "650 KB", "net"),
        Package("jq",         "1.7.1",  "Lightweight JSON processor",          PackageStatus.AVAILABLE, "420 KB", "utils"),
        Package("ruby",       "3.3.0",  "Dynamic, scripting language",         PackageStatus.AVAILABLE, "16 MB",  "interpreters"),
        Package("perl",       "5.38.2", "Practical extraction language",       PackageStatus.AVAILABLE, "22 MB",  "interpreters"),
        Package("clang",      "18.1.0", "C language family compiler",          PackageStatus.UPGRADABLE,"85 MB",  "devel"),
    )
}
