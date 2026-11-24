package ru.dcns.soty

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.InputStream

class MainActivity : FlutterFragmentActivity() {
    private var meshResult: MethodChannel.Result? = null
    private var sotyEngine: FlutterEngine? = null

    // Backup export/restore uses the system document picker, so the file lives
    // wherever the user chose (Downloads, Drive, a USB stick) instead of app
    // storage that is wiped with the app.
    private var saveResult: MethodChannel.Result? = null
    private var saveBytes: ByteArray? = null
    private var savePath: String? = null
    private var pickResult: MethodChannel.Result? = null
    private var pickAsPath = false

    private val createBackup = registerForActivityResult(
        ActivityResultContracts.CreateDocument("application/octet-stream"),
    ) { uri ->
        val result = saveResult
        val bytes = saveBytes
        val path = savePath
        saveResult = null
        saveBytes = null
        savePath = null
        if (uri == null || (bytes == null && path == null)) {
            result?.success(null)
            return@registerForActivityResult
        }
        Thread {
            val name = try {
                contentResolver.openOutputStream(uri, "wt")?.use { out ->
                    if (bytes != null) {
                        out.write(bytes)
                        out.flush()
                    } else {
                        File(path!!).inputStream().use { input ->
                            if (copyBackup(input, out) == null) {
                                throw IllegalStateException("backup is too large")
                            }
                        }
                    }
                }
                uri.lastPathSegment
            } catch (error: Exception) {
                null
            }
            runOnUiThread {
                if (name == null) {
                    result?.error("write_failed", "could not write backup", null)
                } else {
                    result?.success(name)
                }
            }
        }.start()
    }

    private val openBackup = registerForActivityResult(
        ActivityResultContracts.OpenDocument(),
    ) { uri ->
        val result = pickResult
        val asPath = pickAsPath
        pickResult = null
        pickAsPath = false
        if (uri == null) {
            result?.success(null)
            return@registerForActivityResult
        }
        Thread {
            if (asPath) {
                val temp = File(
                    cacheDir,
                    "soty-restore-${System.currentTimeMillis()}.soty",
                )
                val ok = try {
                    val copied = contentResolver.openInputStream(uri)?.use { input ->
                        temp.outputStream().use { out -> copyBackup(input, out) }
                    }
                    copied != null
                } catch (error: Exception) {
                    false
                }
                if (!ok) temp.delete()
                runOnUiThread {
                    if (ok) {
                        result?.success(temp.absolutePath)
                    } else {
                        result?.error("read_failed", "could not read backup", null)
                    }
                }
            } else {
                val bytes = try {
                    contentResolver.openInputStream(uri)?.use { readBackup(it) }
                } catch (error: Exception) {
                    null
                }
                runOnUiThread {
                    if (bytes == null) {
                        result?.error("read_failed", "could not read backup", null)
                    } else {
                        result?.success(bytes)
                    }
                }
            }
        }.start()
    }

    // The engine outlives the activity: swiping the task away must not kill
    // the Dart isolate that owns the mesh radios and the relay connections,
    // or the foreground service would keep an empty process alive.
    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        var engine = sotyEngine
        if (engine == null) {
            engine = FlutterEngine(context).also {
                it.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint.createDefault(),
                )
                GeneratedPluginRegistrant.registerWith(it)
            }
            sotyEngine = engine
        }
        return engine
    }

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Android has no Dart API for reaching the screen where a user switches
        // notifications on, and a denied POST_NOTIFICATIONS is otherwise a dead
        // end: the app can neither show banners nor ask again.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ru.dcns.soty/system_settings",
        ).setMethodCallHandler { call, result ->
            if (call.method != "openAppNotificationSettings") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            try {
                startActivity(intent)
                result.success(null)
            } catch (error: Exception) {
                result.error("unavailable", error.message, null)
            }
        }
        // Android 12+ gates BLE scanning, connecting and advertising behind
        // runtime permissions. The mesh plugin has no way to ask for them and
        // swallows the resulting SecurityException, so the offline transport
        // silently does nothing without this.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ru.dcns.soty/mesh_permissions",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(meshStatus())
                "request" -> requestMeshPermissions(result)
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ru.dcns.soty/background_service",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    try {
                        SotyBackgroundService.start(this)
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("unavailable", error.message, null)
                    }
                }
                "stop" -> {
                    SotyBackgroundService.stop(this)
                    result.success(null)
                }
                "isIgnoringBatteryOptimizations" ->
                    result.success(isIgnoringBatteryOptimizations())
                "requestIgnoreBatteryOptimizations" -> {
                    requestIgnoreBatteryOptimizations()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        // Encrypted backup: only the user's chosen document is touched, and
        // the read path is capped so a hostile file cannot exhaust memory.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ru.dcns.soty/backup",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "save" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes == null || bytes.isEmpty()) {
                        result.error("bad_backup", "missing bytes", null)
                        return@setMethodCallHandler
                    }
                    val name = call.argument<String>("name") ?: "soty-backup"
                    if (saveResult != null) {
                        result.error("busy", "a save dialog is already open", null)
                        return@setMethodCallHandler
                    }
                    saveResult = result
                    saveBytes = bytes
                    createBackup.launch(name)
                }
                "savePath" -> {
                    val path = call.argument<String>("path")
                    if (path == null || !File(path).isFile) {
                        result.error("bad_backup", "missing file", null)
                        return@setMethodCallHandler
                    }
                    val name = call.argument<String>("name") ?: "soty-backup"
                    if (saveResult != null) {
                        result.error("busy", "a save dialog is already open", null)
                        return@setMethodCallHandler
                    }
                    saveResult = result
                    saveBytes = null
                    savePath = path
                    createBackup.launch(name)
                }
                "pick" -> {
                    if (pickResult != null) {
                        result.error("busy", "a picker is already open", null)
                        return@setMethodCallHandler
                    }
                    pickResult = result
                    pickAsPath = false
                    openBackup.launch(arrayOf("*/*"))
                }
                "pickPath" -> {
                    if (pickResult != null) {
                        result.error("busy", "a picker is already open", null)
                        return@setMethodCallHandler
                    }
                    pickResult = result
                    pickAsPath = true
                    openBackup.launch(arrayOf("*/*"))
                }
                else -> result.notImplemented()
            }
        }
        // Identity seeds live in the Android Keystore, not in the SQLite file.
        SecureIdentityChannel(this).register(
            flutterEngine.dartExecutor.binaryMessenger,
        )
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ru.dcns.soty/share",
        ).setMethodCallHandler { call, result ->
            if (call.method != "shareText") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val text = call.argument<String>("text") ?: ""
            val sendIntent: Intent = Intent().apply {
                action = Intent.ACTION_SEND
                putExtra(Intent.EXTRA_TEXT, text)
                type = "text/plain"
            }
            val chooser = Intent.createChooser(sendIntent, null).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            try {
                startActivity(chooser)
                result.success(null)
            } catch (error: Exception) {
                result.error("unavailable", error.message, null)
            }
        }
        // Tapping a link in a message opens it in the system browser. Only
        // http/https are accepted: a message is untrusted input, and the app
        // must never be tricked into launching an arbitrary intent.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ru.dcns.soty/url",
        ).setMethodCallHandler { call, result ->
            if (call.method != "openUrl") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val url = call.argument<String>("url") ?: ""
            val scheme = Uri.parse(url).scheme?.lowercase()
            if (scheme != "http" && scheme != "https") {
                result.error("unsupported_scheme", "only http/https", null)
                return@setMethodCallHandler
            }
            val viewIntent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            try {
                startActivity(viewIntent)
                result.success(true)
            } catch (error: Exception) {
                result.error("unavailable", error.message, null)
            }
        }
        // In-app updates: the Dart side downloads the APK into cache/updates
        // and asks here to hand it to the package installer. Only that one
        // directory is served, and installing still requires the user's
        // "install unknown apps" consent.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ru.dcns.soty/update",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canInstall" -> result.success(canInstallPackages())
                "install" -> startUpdateInstall(
                    call.argument<String>("path"),
                    result,
                )
                "certificate" -> result.success(
                    certificateSha256(call.argument<String>("path")),
                )
                else -> result.notImplemented()
            }
        }
    }

    /** SHA-256 of an APK's signer, or of this package when [path] is null. */
    private fun certificateSha256(path: String?): String? {
        return try {
            val info = if (path.isNullOrEmpty()) {
                if (Build.VERSION.SDK_INT >= 28) {
                    packageManager.getPackageInfo(
                        packageName,
                        PackageManager.GET_SIGNING_CERTIFICATES,
                    )
                } else {
                    @Suppress("DEPRECATION")
                    packageManager.getPackageInfo(
                        packageName,
                        PackageManager.GET_SIGNATURES,
                    )
                }
            } else {
                val file = File(path)
                if (!file.isFile) return null
                if (Build.VERSION.SDK_INT >= 28) {
                    packageManager.getPackageArchiveInfo(
                        file.absolutePath,
                        PackageManager.GET_SIGNING_CERTIFICATES,
                    )
                } else {
                    @Suppress("DEPRECATION")
                    packageManager.getPackageArchiveInfo(
                        file.absolutePath,
                        PackageManager.GET_SIGNATURES,
                    )
                }
            } ?: return null
            val signature = if (Build.VERSION.SDK_INT >= 28) {
                info.signingInfo?.apkContentsSigners?.firstOrNull()
            } else {
                @Suppress("DEPRECATION")
                info.signatures?.firstOrNull()
            } ?: return null
            val digest = java.security.MessageDigest.getInstance("SHA-256")
                .digest(signature.toByteArray())
            digest.joinToString("") { "%02x".format(it) }
        } catch (error: Exception) {
            null
        }
    }

    /** Copies a backup in 64 KiB buffers; mirrors the Dart limit. */
    private fun copyBackup(
        input: InputStream,
        output: java.io.OutputStream,
    ): Long? {
        val buffer = ByteArray(64 * 1024)
        var total = 0L
        while (true) {
            val read = input.read(buffer)
            if (read < 0) break
            total += read
            if (total > MAX_BACKUP_BYTES) return null
            output.write(buffer, 0, read)
        }
        output.flush()
        return total
    }

    /** Reads at most [MAX_BACKUP_BYTES]; mirrors the Dart limit. */
    private fun readBackup(input: InputStream): ByteArray? {
        val out = ByteArrayOutputStream()
        val buffer = ByteArray(16 * 1024)
        var total = 0
        while (true) {
            val read = input.read(buffer)
            if (read < 0) break
            total += read
            if (total > MAX_BACKUP_BYTES) return null
            out.write(buffer, 0, read)
        }
        return out.toByteArray()
    }

    /** Android 8+ gates sideloading behind a per-app "install unknown apps"
     * toggle; [Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES] is the only way to
     * turn it on. */
    private fun canInstallPackages(): Boolean =
        packageManager.canRequestPackageInstalls()

    private fun startUpdateInstall(path: String?, result: MethodChannel.Result) {
        if (path.isNullOrEmpty()) {
            result.error("bad_path", "missing path", null)
            return
        }
        if (!canInstallPackages()) {
            val settingsIntent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            ).setData(Uri.parse("package:$packageName"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                startActivity(settingsIntent)
            } catch (error: Exception) {
                result.error("unavailable", error.message, null)
                return
            }
            result.success("needsPermission")
            return
        }
        try {
            val apk = File(path).canonicalFile
            val updatesRoot = File(cacheDir, "updates").canonicalFile
            val insideUpdates = apk.path.startsWith(
                updatesRoot.path + File.separator,
            )
            if (!insideUpdates) {
                result.error("bad_path", "outside the update directory", null)
                return
            }
            if (!apk.isFile) {
                result.error("missing", "no downloaded apk", null)
                return
            }
            val uri = FileProvider.getUriForFile(
                this,
                "$packageName.updates",
                apk,
            )
            val installIntent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(
                    uri,
                    "application/vnd.android.package-archive",
                )
                addFlags(
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_ACTIVITY_NEW_TASK,
                )
            }
            startActivity(installIntent)
            result.success("started")
        } catch (error: Exception) {
            result.error("unavailable", error.message, null)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == meshRequestCode) {
            val result = meshResult
            meshResult = null
            result?.success(meshStatus())
        }
    }

    private fun requestMeshPermissions(result: MethodChannel.Result) {
        val missing = meshPermissions().filter {
            ContextCompat.checkSelfPermission(this, it) !=
                PackageManager.PERMISSION_GRANTED
        }
        if (missing.isEmpty() || meshResult != null) {
            result.success(meshStatus())
            return
        }
        meshResult = result
        ActivityCompat.requestPermissions(
            this,
            missing.toTypedArray(),
            meshRequestCode,
        )
    }

    /** Granted and denied runtime permissions, so Dart can tell "denied" from
     * "not applicable on this Android version". */
    private fun meshStatus(): Map<String, Any> {
        val required = meshPermissions()
        val granted = mutableListOf<String>()
        val denied = mutableListOf<String>()
        for (permission in required) {
            val state = ContextCompat.checkSelfPermission(this, permission)
            if (state == PackageManager.PERMISSION_GRANTED) {
                granted.add(permission)
            } else {
                denied.add(permission)
            }
        }
        return mapOf(
            "sdk" to Build.VERSION.SDK_INT,
            "required" to required,
            "granted" to granted,
            "denied" to denied,
        )
    }

    /** Only the permissions that are runtime permissions on this release.
     * BLE came in at API 31, NEARBY_WIFI_DEVICES at API 33; below API 31 the
     * legacy Bluetooth permissions are install-time grants but scanning still
     * needs a runtime location grant, so that is the one to ask for there. */
    private fun meshPermissions(): List<String> {
        val permissions = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            permissions.add(Manifest.permission.BLUETOOTH_SCAN)
            permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
            permissions.add(Manifest.permission.BLUETOOTH_ADVERTISE)
        } else {
            permissions.add(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissions.add(Manifest.permission.NEARBY_WIFI_DEVICES)
        }
        return permissions
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        val power = getSystemService(PowerManager::class.java)
        return power.isIgnoringBatteryOptimizations(packageName)
    }

    private fun requestIgnoreBatteryOptimizations() {
        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
            .setData(Uri.parse("package:$packageName"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            startActivity(intent)
        } catch (error: Exception) {
            // Play-restricted on some builds; the Settings row falls back to a
            // manual "No restrictions" how-to in the README.
        }
    }

    private companion object {
        const val meshRequestCode = 0x5017
        const val MAX_BACKUP_BYTES = 1024 * 1024 * 1024
    }
}