package com.fluttermeshnetwork.flutter_mesh_network

import android.app.Activity
import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.charset.StandardCharsets
import java.util.UUID

/**
 * Handles BLE Peripheral mode: GATT server + advertising.
 *
 * Channel: `flutter_mesh_network/ble`
 *
 * Advertising name prefix: "MSH_"
 * Uses the Nordic UART Service (NUS) UUID layout for TX/RX characteristics.
 */
class BlePeripheralHandler(private val context: Context) {

    companion object {
        private const val TAG = "MshBle"
        private const val NAME_PREFIX = "MSH_"

        // Nordic UART Service UUIDs
        val SERVICE_UUID: UUID  = UUID.fromString("6e400001-b5a3-f393-e0a9-e50e24dcca9e")
        val TX_CHAR_UUID: UUID  = UUID.fromString("6e400002-b5a3-f393-e0a9-e50e24dcca9e") // client writes
        val RX_CHAR_UUID: UUID  = UUID.fromString("6e400003-b5a3-f393-e0a9-e50e24dcca9e") // server notifies

        // Client Characteristic Configuration Descriptor
        val CCCD_UUID: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

        // Custom manufacturer ID (0x4D53 = "MS") and the version byte that
        // follows it: a scanner meeting both knows it is this mesh.
        const val MANUFACTURER_ID = 0x4D53
        const val MANUFACTURER_VERSION: Byte = 0x01

        // Longest device name that fits a scan response: 31 bytes of packet
        // minus the two bytes of the AD length/type header.
        const val MAX_NAME_BYTES = 29
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var methodChannel: MethodChannel? = null
    private var activity: Activity? = null

    // Bluetooth stack
    private var bluetoothManager: BluetoothManager? = null
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var advertiser: BluetoothLeAdvertiser? = null
    private var gattServer: BluetoothGattServer? = null

    // State
    private var isAdvertising = false
    private var isGattRunning = false

    /// Adapter name observed before we prefixed it, restored on stop() so the
    /// phone does not keep a "MSH_" name after the mesh goes down.
    private var originalAdapterName: String? = null

    // Connected / subscribed devices
    private val connectedDevices = mutableMapOf<String, BluetoothDevice>()
    private val subscribedDevices = mutableSetOf<String>()

    // Incoming message buffer per device (chunked writes)
    private val incomingBuffers = mutableMapOf<String, StringBuilder>()

    // GATT characteristic reference for notifications
    private var rxCharacteristic: BluetoothGattCharacteristic? = null

    fun setMethodChannel(channel: MethodChannel) {
        methodChannel = channel
    }

    fun setActivity(act: Activity?) {
        activity = act
    }

    // =========================================================================
    // MethodCall dispatch
    // =========================================================================

    fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> result.success(initialize())

            "startGattServer" -> result.success(startGattServer())

            "startAdvertising" -> {
                val name = call.argument<String>("userName") ?: ""
                result.success(startAdvertising(name))
            }

            "stopAdvertising" -> {
                stopAdvertising()
                result.success(true)
            }

            "updateLocation" -> {
                result.success(true)
            }

            "notifyAll" -> {
                val data = call.argument<String>("data") ?: ""
                val count = notifyAllSubscribers(data.toByteArray(Charsets.UTF_8))
                result.success(count)
            }

            "getState" -> result.success(getState())

            "stop" -> {
                stop()
                result.success(true)
            }

            else -> result.notImplemented()
        }
    }

    // =========================================================================
    // Initialization
    // =========================================================================

    private fun initialize(): Boolean {
        bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        bluetoothAdapter = bluetoothManager?.adapter

        if (bluetoothAdapter == null) {
            Log.e(TAG, "Bluetooth not available")
            return false
        }

        advertiser = bluetoothAdapter?.bluetoothLeAdvertiser
        if (advertiser == null) {
            Log.e(TAG, "BLE Advertising not supported")
            return false
        }

        return true
    }

    // =========================================================================
    // GATT Server
    // =========================================================================

    private fun startGattServer(): Boolean {
        if (isGattRunning) return true

        try {
            gattServer = bluetoothManager?.openGattServer(context, gattCallback)
            if (gattServer == null) {
                Log.e(TAG, "Failed to open GATT server")
                return false
            }

            val svc = createGattService()
            val added = gattServer?.addService(svc)
            if (added != true) {
                Log.e(TAG, "Failed to add GATT service")
                isGattRunning = false
                return false
            }
            isGattRunning = true
            Log.d(TAG, "GATT server started")
            return true
        } catch (e: SecurityException) {
            Log.e(TAG, "GATT server permission denied: ${e.message}")
            return false
        } catch (e: Exception) {
            Log.e(TAG, "GATT server error: ${e.message}")
            return false
        }
    }

    private fun createGattService(): BluetoothGattService {
        val service = BluetoothGattService(SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)

        // TX — client writes mesh messages here
        val txChar = BluetoothGattCharacteristic(
            TX_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_WRITE or
                    BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE,
            BluetoothGattCharacteristic.PERMISSION_WRITE
        )

        // RX — server notifies mesh messages to clients
        rxCharacteristic = BluetoothGattCharacteristic(
            RX_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ or
                    BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ
        )

        val cccd = BluetoothGattDescriptor(
            CCCD_UUID,
            BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE
        )
        rxCharacteristic!!.addDescriptor(cccd)

        service.addCharacteristic(txChar)
        service.addCharacteristic(rxCharacteristic!!)
        return service
    }

    // ---- GATT callbacks ----------------------------------------------------

    private val gattCallback = object : BluetoothGattServerCallback() {

        override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
            try {
                val address = device.address
                when (newState) {
                    BluetoothGattServer.STATE_CONNECTED -> {
                        Log.d(TAG, "Device connected: $address")
                        connectedDevices[address] = device
                        incomingBuffers[address] = StringBuilder()
                    }
                    BluetoothGattServer.STATE_DISCONNECTED -> {
                        Log.d(TAG, "Device disconnected: $address")
                        connectedDevices.remove(address)
                        subscribedDevices.remove(address)
                        incomingBuffers.remove(address)
                    }
                }
            } catch (e: SecurityException) {
                Log.e(TAG, "Connection state change error: ${e.message}")
            }
        }

        override fun onCharacteristicWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            characteristic: BluetoothGattCharacteristic,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray?
        ) {
            try {
                if (characteristic.uuid == TX_CHAR_UUID && value != null) {
                    handleIncomingWrite(device, value)
                }
                if (responseNeeded) {
                    try {
                        gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
                    } catch (_: Exception) {}
                }
            } catch (e: SecurityException) {
                Log.e(TAG, "Write request error: ${e.message}")
            }
        }

        override fun onCharacteristicReadRequest(
            device: BluetoothDevice,
            requestId: Int,
            offset: Int,
            characteristic: BluetoothGattCharacteristic
        ) {
            try {
                if (characteristic.uuid == RX_CHAR_UUID) {
                    try {
                        gattServer?.sendResponse(
                            device, requestId, BluetoothGatt.GATT_SUCCESS, 0,
                            characteristic.value ?: byteArrayOf()
                        )
                    } catch (_: Exception) {}
                }
            } catch (e: SecurityException) {
                Log.e(TAG, "Read request error: ${e.message}")
            }
        }

        override fun onDescriptorWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            descriptor: BluetoothGattDescriptor,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray?
        ) {
            try {
                if (descriptor.uuid == CCCD_UUID) {
                    val address = device.address
                    if (value?.contentEquals(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE) == true) {
                        subscribedDevices.add(address)
                        Log.d(TAG, "Notifications enabled for $address")
                    } else {
                        subscribedDevices.remove(address)
                        Log.d(TAG, "Notifications disabled for $address")
                    }
                }
                if (responseNeeded) {
                    try {
                        gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
                    } catch (_: Exception) {}
                }
            } catch (e: SecurityException) {
                Log.e(TAG, "Descriptor write error: ${e.message}")
            }
        }

        override fun onMtuChanged(device: BluetoothDevice, mtu: Int) {
            Log.d(TAG, "MTU changed: $mtu for ${device.address}")
        }
    }

    // ---- Incoming write assembly -------------------------------------------

    private fun handleIncomingWrite(device: BluetoothDevice, value: ByteArray) {
        val address = device.address
        val chunk = String(value, StandardCharsets.UTF_8)
        Log.d(TAG, "Write from $address: ${chunk.take(50)}...")

        val buffer = incomingBuffers.getOrPut(address) { StringBuilder() }
        buffer.append(chunk)

        val accumulated = buffer.toString()
        if (accumulated.endsWith("\n\n") || isCompleteJson(accumulated)) {
            val messageData = accumulated.trimEnd('\n')
            incomingBuffers[address] = StringBuilder()

            Log.d(TAG, "Complete message from $address (${messageData.length} chars)")

            mainHandler.post {
                methodChannel?.invokeMethod("onBleMessageReceived", mapOf(
                    "deviceId" to address,
                    "data" to messageData
                ))
            }
        }
    }

    private fun isCompleteJson(str: String): Boolean {
        val trimmed = str.trim()
        return try {
            if (trimmed.startsWith("{") && trimmed.endsWith("}")) {
                org.json.JSONObject(trimmed)
                true
            } else false
        } catch (_: Exception) {
            false
        }
    }

    // =========================================================================
    // BLE Advertising
    // =========================================================================

    private fun startAdvertising(name: String): Boolean {
        if (isAdvertising) stopAdvertising()

        renameAdapter(name)

        try {
            val settings = AdvertiseSettings.Builder()
                .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
                .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
                .setConnectable(true)
                .setTimeout(0)
                .build()

            advertiser?.startAdvertising(
                settings,
                buildAdvertiseData(),
                buildScanResponse(),
                advertiseCallback
            )
            Log.d(TAG, "Advertising started as ${bluetoothAdapter?.name}")
            return true
        } catch (e: SecurityException) {
            Log.e(TAG, "Advertising permission denied: ${e.message}")
            return false
        } catch (e: Exception) {
            Log.e(TAG, "Advertising error: ${e.message}")
            return false
        }
    }

    /**
     * The name travels in the scan response, which is read from the adapter
     * name, so the adapter is renamed with the "MSH_" prefix and truncated to
     * what the 31-byte scan response can hold. The previous name is kept so
     * stop() can put it back.
     */
    private fun renameAdapter(name: String) {
        try {
            val adapter = bluetoothAdapter ?: return
            if (originalAdapterName == null) {
                originalAdapterName = adapter.name
            }
            adapter.name = NAME_PREFIX + truncateToBytes(name, MAX_NAME_BYTES - NAME_PREFIX.length)
        } catch (e: SecurityException) {
            Log.w(TAG, "Cannot rename the adapter: ${e.message}")
        }
    }

    /** Cuts [value] so its UTF-8 encoding fits [maxBytes] without splitting a code point. */
    private fun truncateToBytes(value: String, maxBytes: Int): String {
        val bytes = value.toByteArray(StandardCharsets.UTF_8)
        if (bytes.size <= maxBytes) return value
        var end = maxBytes
        while (end > 0 && (bytes[end].toInt() and 0xC0) == 0x80) end--
        return String(bytes, 0, end, StandardCharsets.UTF_8)
    }

    /**
     * A legacy advertising packet holds 31 bytes: the stack adds the flags AD
     * (3), the 128-bit service UUID costs 18 and the manufacturer marker 5,
     * which leaves room for nothing else. The name is therefore moved to the
     * scan response and the coordinates are not advertised at all — they never
     * fit and their absence is what used to push the packet over the limit.
     */
    private fun buildAdvertiseData(): AdvertiseData =
        AdvertiseData.Builder()
            .addServiceUuid(ParcelUuid(SERVICE_UUID))
            .addManufacturerData(MANUFACTURER_ID, byteArrayOf(MANUFACTURER_VERSION))
            .build()

    private fun buildScanResponse(): AdvertiseData =
        AdvertiseData.Builder()
            .setIncludeDeviceName(true)
            .build()


    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
            isAdvertising = true
            Log.d(TAG, "Advertising started successfully")
            mainHandler.post {
                methodChannel?.invokeMethod("onBleAdvertisingStarted", true)
            }
        }

        override fun onStartFailure(errorCode: Int) {
            isAdvertising = false
            val reason = when (errorCode) {
                ADVERTISE_FAILED_DATA_TOO_LARGE         -> "data too large"
                ADVERTISE_FAILED_TOO_MANY_ADVERTISERS   -> "too many advertisers"
                ADVERTISE_FAILED_ALREADY_STARTED         -> "already started"
                ADVERTISE_FAILED_INTERNAL_ERROR          -> "internal error"
                ADVERTISE_FAILED_FEATURE_UNSUPPORTED     -> "feature unsupported"
                else                                     -> "unknown ($errorCode)"
            }
            Log.e(TAG, "Advertising failed: $reason")
            mainHandler.post {
                methodChannel?.invokeMethod("onBleAdvertisingStarted", false)
            }
        }
    }

    private fun stopAdvertising() {
        if (!isAdvertising) return
        try { advertiser?.stopAdvertising(advertiseCallback) } catch (_: SecurityException) {}
        isAdvertising = false
        Log.d(TAG, "Advertising stopped")
    }

    // =========================================================================
    // Notify (GATT Server -> connected clients)
    // =========================================================================

    private fun notifyAllSubscribers(data: ByteArray): Int {
        val rx = rxCharacteristic ?: return 0
        var count = 0

        for (address in subscribedDevices.toList()) {
            val device = connectedDevices[address] ?: continue
            try {
                rx.value = data
                if (gattServer?.notifyCharacteristicChanged(device, rx, false) == true) count++
            } catch (e: SecurityException) {
                Log.e(TAG, "Notify error for $address: ${e.message}")
            }
        }

        Log.d(TAG, "Notified $count/${subscribedDevices.size} subscribers")
        return count
    }

    // =========================================================================
    // State & lifecycle
    // =========================================================================

    private fun getState(): Map<String, Any> = mapOf(
        "isAdvertising" to isAdvertising,
        "isGattRunning" to isGattRunning,
        "connectedCount" to connectedDevices.size,
        "subscribedCount" to subscribedDevices.size
    )

    fun stop() {
        stopAdvertising()

        try { gattServer?.close() } catch (_: Exception) {}
        gattServer = null
        isGattRunning = false

        connectedDevices.clear()
        subscribedDevices.clear()
        incomingBuffers.clear()

        // Put the name the phone had before the mesh renamed it
        originalAdapterName?.let { previous ->
            try { bluetoothAdapter?.name = previous } catch (_: SecurityException) {}
        }
        originalAdapterName = null

        Log.d(TAG, "BLE Peripheral stopped")
    }
}
