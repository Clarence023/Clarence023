package com.offgrid.meshchat.mesh

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.*
import android.content.Context
import android.os.ParcelUuid

class BleTransport(context: Context) {
    private val adapter = (context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager).adapter
    private val scanner: BluetoothLeScanner? = adapter.bluetoothLeScanner
    private val advertiser: BluetoothLeAdvertiser? = adapter.bluetoothLeAdvertiser

    private val serviceUuid = ParcelUuid.fromString("0000ff11-0000-1000-8000-00805f9b34fb")

    fun startAdvertising(nodeId: String) {
        val settings = AdvertiseSettings.Builder().setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_POWER).build()
        val data = AdvertiseData.Builder().addServiceUuid(serviceUuid).setIncludeDeviceName(false).build()
        advertiser?.startAdvertising(settings, data, object : AdvertiseCallback() {})
    }

    fun startScan(onNodeFound: (DiscoveredNode) -> Unit) {
        val filter = ScanFilter.Builder().setServiceUuid(serviceUuid).build()
        val settings = ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_POWER).build()
        scanner?.startScan(listOf(filter), settings, object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                val id = result.device.address
                onNodeFound(DiscoveredNode(id, "User-${id.takeLast(4)}", 0xFF0EA5E9, 1, result.rssi))
            }
        })
    }

    fun broadcast(payload: ByteArray) {
        // Placeholder for GATT fragmentation + rebroadcast in mesh overlay.
    }
}
