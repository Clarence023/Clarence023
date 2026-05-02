package com.offgrid.meshchat.mesh

import android.content.Context
import android.net.wifi.p2p.WifiP2pManager

class WifiDirectTransport(context: Context) {
    private val manager = context.getSystemService(Context.WIFI_P2P_SERVICE) as WifiP2pManager
    private val channel = manager.initialize(context, context.mainLooper, null)

    fun startDiscovery(onNodeFound: (DiscoveredNode) -> Unit) {
        manager.discoverPeers(channel, object : WifiP2pManager.ActionListener {
            override fun onSuccess() = Unit
            override fun onFailure(reason: Int) = Unit
        })
        // In production this should be fed by WIFI_P2P_PEERS_CHANGED_ACTION receiver.
    }

    fun broadcast(payload: ByteArray) {
        // Placeholder for Wi-Fi Direct socket broadcast implementation.
    }
}
