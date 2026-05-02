package com.offgrid.meshchat.data

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface MessageDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(message: MessageEntity)

    @Query("SELECT * FROM messages WHERE (fromNodeId = :a AND toNodeId = :b) OR (fromNodeId = :b AND toNodeId = :a) ORDER BY createdAtEpochMillis")
    fun conversation(a: String, b: String): Flow<List<MessageEntity>>

    @Query("SELECT * FROM messages WHERE delivered = 0 AND expiryAtEpochMillis > :now")
    suspend fun pending(now: Long): List<MessageEntity>

    @Query("UPDATE messages SET delivered = 1, deliveredAtEpochMillis = :deliveredAt WHERE id = :id")
    suspend fun markDelivered(id: String, deliveredAt: Long)
}
