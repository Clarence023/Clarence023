package com.offgrid.meshchat.mesh

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.UUID

data class DiscoveredNode(
    val nodeId: String,
    val username: String,
    val avatarColor: Long,
    val hops: Int,
    val rssi: Int
)

class MeshNodeManager(context: Context) {
    private val bleTransport = BleTransport(context)
    private val wifiTransport = WifiDirectTransport(context)

    private val _nodes = MutableStateFlow<List<DiscoveredNode>>(emptyList())
    val nodes: StateFlow<List<DiscoveredNode>> = _nodes.asStateFlow()

    val localNodeId: String = UUID.randomUUID().toString()

    fun start() {
        bleTransport.startAdvertising(localNodeId)
        bleTransport.startScan { node -> upsertNode(node) }
        wifiTransport.startDiscovery { node -> upsertNode(node) }
    }

    fun broadcast(payload: ByteArray) {
        bleTransport.broadcast(payload)
        wifiTransport.broadcast(payload)
    }

    private fun upsertNode(node: DiscoveredNode) {
        val updated = _nodes.value.toMutableList()
        val index = updated.indexOfFirst { it.nodeId == node.nodeId }
        if (index >= 0) updated[index] = node else updated.add(node)
        _nodes.value = updated.sortedBy { it.hops }
    }
}
