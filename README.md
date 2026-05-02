# OffGrid Mesh Chat (Android)

Offline-first Android mesh messaging app prototype using BLE + Wi-Fi Direct, Room queueing, and Curve25519 shared-secret derivation.

## Implemented foundations
- BLE advertiser + scanner bootstrap (`BleTransport`)
- Wi-Fi Direct peer discovery bootstrap (`WifiDirectTransport`)
- In-memory mesh graph routing with BFS next-hop (`MeshRouter`)
- Room schema for 24-hour queued delivery + device-delivery read receipts (`MessageEntity`, `MessageDao`)
- Curve25519 precomputation (`CryptoEngine`) via LazySodium/Libsodium
- Dark emergency-oriented Compose UI listing discovered peers and hop count

## Important notes
This commit provides a runnable foundation and architecture skeleton. Production mesh transport still needs:
- reliable BLE GATT chunking/reassembly
- Wi-Fi Direct socket session management
- packet signatures, replay protection, and ACK protocol
- background execution hardening + battery profiling
