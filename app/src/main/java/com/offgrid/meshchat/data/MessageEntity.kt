package com.offgrid.meshchat.data

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "messages")
data class MessageEntity(
    @PrimaryKey val id: String,
    val fromNodeId: String,
    val toNodeId: String,
    val body: String,
    val createdAtEpochMillis: Long,
    val expiryAtEpochMillis: Long,
    val hopCount: Int,
    val delivered: Boolean,
    val deliveredAtEpochMillis: Long?
)
