package com.offgrid.meshchat.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.offgrid.meshchat.mesh.MeshNodeManager

@Composable
fun OffGridApp(meshNodeManager: MeshNodeManager) {
    val nodes by meshNodeManager.nodes.collectAsState()
    LaunchedEffect(Unit) { meshNodeManager.start() }

    Scaffold(
        floatingActionButton = {
            FloatingActionButton(onClick = { meshNodeManager.broadcast("EMERGENCY BROADCAST".toByteArray()) }) {
                Text("SOS")
            }
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .fillMaxSize()
                .background(Brush.radialGradient(listOf(Color(0xFF11263B), Color(0xFF060A12))))
                .padding(16.dp)
        ) {
            Text("OffGrid Mesh Chat", style = MaterialTheme.typography.headlineSmall, color = Color.White)
            Spacer(Modifier.height(12.dp))
            Text("Nearby users", color = Color(0xFF90CAF9))
            LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                items(nodes) { node ->
                    Card(colors = CardDefaults.cardColors(containerColor = Color(0xFF0F172A))) {
                        Row(Modifier.fillMaxWidth().padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                            Text(node.username, color = Color.White, modifier = Modifier.weight(1f))
                            Text("${node.hops} hop(s)", color = Color(0xFF80CBC4))
                            Spacer(Modifier.width(8.dp))
                            Text("RSSI ${node.rssi}", color = Color(0xFFB0BEC5))
                        }
                    }
                }
            }
        }
    }
}
