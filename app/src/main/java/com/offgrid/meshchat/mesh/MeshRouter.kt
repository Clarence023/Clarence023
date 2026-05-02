package com.offgrid.meshchat.mesh

import java.util.ArrayDeque

data class MeshPacket(
    val id: String,
    val source: String,
    val destination: String,
    val ttl: Int,
    val payload: ByteArray
)

class MeshRouter {
    private val adjacency: MutableMap<String, MutableSet<String>> = mutableMapOf()

    fun updateLink(a: String, b: String) {
        adjacency.getOrPut(a) { mutableSetOf() }.add(b)
        adjacency.getOrPut(b) { mutableSetOf() }.add(a)
    }

    fun nextHop(source: String, destination: String): String? {
        if (source == destination) return destination
        val q = ArrayDeque<String>()
        val parent = mutableMapOf<String, String?>()
        q.add(source)
        parent[source] = null
        while (q.isNotEmpty()) {
            val node = q.removeFirst()
            adjacency[node].orEmpty().forEach { n ->
                if (n !in parent) {
                    parent[n] = node
                    if (n == destination) {
                        var step = destination
                        while (parent[step] != source) step = parent[step] ?: return null
                        return step
                    }
                    q.add(n)
                }
            }
        }
        return null
    }
}
