package com.offgrid.meshchat.crypto

import com.goterl.lazysodium.LazySodiumAndroid
import com.goterl.lazysodium.interfaces.Box
import com.goterl.lazysodium.utils.KeyPair

class CryptoEngine {
    private val sodium = LazySodiumAndroid("offgrid")
    val localKeyPair: KeyPair = sodium.cryptoBoxKeypair()

    fun sharedSecret(peerPublicKey: ByteArray): ByteArray {
        val out = ByteArray(Box.BEFORENMBYTES)
        sodium.cryptoBoxBeforenm(out, peerPublicKey, localKeyPair.secretKey.asBytes)
        return out
    }
}
