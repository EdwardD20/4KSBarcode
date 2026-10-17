//
// XPaddle
// NetworkManager.kt
//

package org.danleys.xpaddle

import android.content.Context
import android.os.Build
import com.google.android.gms.nearby.Nearby
import com.google.android.gms.nearby.connection.AdvertisingOptions
import com.google.android.gms.nearby.connection.ConnectionInfo
import com.google.android.gms.nearby.connection.ConnectionLifecycleCallback
import com.google.android.gms.nearby.connection.ConnectionResolution
import com.google.android.gms.nearby.connection.ConnectionsClient
import com.google.android.gms.nearby.connection.DiscoveredEndpointInfo
import com.google.android.gms.nearby.connection.DiscoveryOptions
import com.google.android.gms.nearby.connection.EndpointDiscoveryCallback
import com.google.android.gms.nearby.connection.Payload
import com.google.android.gms.nearby.connection.PayloadCallback
import com.google.android.gms.nearby.connection.PayloadTransferUpdate
import com.google.android.gms.nearby.connection.Strategy
import org.json.JSONObject

/// Messages exchanged between the two phones during a nearby duel. Kept
/// intentionally tiny: paddle positions never cross the wire — each phone
/// is fully authoritative over the ball while it's on its own screen, and
/// only hands off state when the ball reaches the seam between devices.
sealed class DuelMessage {
    data class Hello(val token: String) : DuelMessage()
    data class BallHandoff(val yFraction: Double, val vyFraction: Double, val speedFraction: Double) : DuelMessage()
    object PointAgainstSender : DuelMessage()
    object Rematch : DuelMessage()

    fun toJson(): String {
        val obj = JSONObject()
        when (this) {
            is Hello -> {
                obj.put("type", "hello")
                obj.put("token", token)
            } // is Hello
            is BallHandoff -> {
                obj.put("type", "ballHandoff")
                obj.put("y", yFraction)
                obj.put("vy", vyFraction)
                obj.put("speed", speedFraction)
            } // is BallHandoff
            is PointAgainstSender -> obj.put("type", "pointAgainstSender")
            is Rematch -> obj.put("type", "rematch")
        } // when (this)
        return obj.toString()
    } // toJson

    companion object {
        fun fromJson(raw: String): DuelMessage? {
            return try {
                val obj = JSONObject(raw)
                when (obj.getString("type")) {
                    "hello" -> Hello(obj.getString("token"))
                    "ballHandoff" -> BallHandoff(obj.getDouble("y"), obj.getDouble("vy"), obj.getDouble("speed"))
                    "pointAgainstSender" -> PointAgainstSender
                    "rematch" -> Rematch
                    else -> null
                } // when (obj.getString("type"))
            } catch (error: Exception) {
                null
            } // try
        } // fromJson
    } // companion object
} // sealed class DuelMessage

enum class DuelConnectionState {
    IDLE, SEARCHING, CONNECTED, LOST
} // enum class DuelConnectionState

/// Thin wrapper around Google Play Services Nearby Connections that
/// auto-discovers and auto-connects to the first nearby phone running the
/// app — no pairing codes, no UI picker. This is the Android counterpart
/// to the iOS app's MultipeerConnectivity-based NetworkManager: both
/// advertise and browse/discover simultaneously, and accept the first
/// peer found. Works over Bluetooth and/or Wi-Fi Direct, so it keeps
/// working with no internet connection as long as the two phones are close.
class NetworkManager(context: Context) {
    private val serviceId = "org.danleys.xpaddle.duel"
    private val connectionsClient: ConnectionsClient = Nearby.getConnectionsClient(context)
    private val myEndpointName = "${Build.MANUFACTURER} ${Build.MODEL}".trim().ifEmpty { "XPaddle Player" }

    var onMessage: ((DuelMessage) -> Unit)? = null
    var onStateChange: ((DuelConnectionState, String?) -> Unit)? = null

    private var connectedEndpointId: String? = null
    private var state: DuelConnectionState = DuelConnectionState.IDLE

    private val payloadCallback = object : PayloadCallback() {
        override fun onPayloadReceived(endpointId: String, payload: Payload) {
            if (payload.type != Payload.Type.BYTES) return // if not a bytes payload
            val bytes = payload.asBytes() ?: return // val bytes = ... ?: return
            DuelMessage.fromJson(String(bytes, Charsets.UTF_8))?.let { onMessage?.invoke(it) }
        } // onPayloadReceived

        override fun onPayloadTransferUpdate(endpointId: String, update: PayloadTransferUpdate) {
            // Payloads here are single small BYTES messages; no progress to track.
        } // onPayloadTransferUpdate
    } // payloadCallback

    private val connectionLifecycleCallback = object : ConnectionLifecycleCallback() {
        override fun onConnectionInitiated(endpointId: String, info: ConnectionInfo) {
            // Auto-accept, mirroring the iOS advertiser's invitationHandler(true, session).
            connectionsClient.acceptConnection(endpointId, payloadCallback)
        } // onConnectionInitiated

        override fun onConnectionResult(endpointId: String, result: ConnectionResolution) {
            if (!result.status.isSuccess) return // if connection failed
            connectedEndpointId = endpointId
            connectionsClient.stopAdvertising()
            connectionsClient.stopDiscovery()
            state = DuelConnectionState.CONNECTED
            onStateChange?.invoke(state, endpointId)
        } // onConnectionResult

        override fun onDisconnected(endpointId: String) {
            if (connectedEndpointId != endpointId) return // if not our current peer
            connectedEndpointId = null
            state = DuelConnectionState.LOST
            onStateChange?.invoke(state, null)
        } // onDisconnected
    } // connectionLifecycleCallback

    private val endpointDiscoveryCallback = object : EndpointDiscoveryCallback() {
        override fun onEndpointFound(endpointId: String, info: DiscoveredEndpointInfo) {
            if (connectedEndpointId != null) return // if already paired
            connectionsClient.requestConnection(myEndpointName, endpointId, connectionLifecycleCallback)
        } // onEndpointFound

        override fun onEndpointLost(endpointId: String) {
            // Nothing to do: we only ever try to pair with one peer at a time.
        } // onEndpointLost
    } // endpointDiscoveryCallback

    fun startSearching() {
        if (state == DuelConnectionState.CONNECTED) return // if already connected
        state = DuelConnectionState.SEARCHING
        onStateChange?.invoke(state, null)

        val advertisingOptions = AdvertisingOptions.Builder().setStrategy(Strategy.P2P_POINT_TO_POINT).build()
        connectionsClient.startAdvertising(myEndpointName, serviceId, connectionLifecycleCallback, advertisingOptions)

        val discoveryOptions = DiscoveryOptions.Builder().setStrategy(Strategy.P2P_POINT_TO_POINT).build()
        connectionsClient.startDiscovery(serviceId, endpointDiscoveryCallback, discoveryOptions)
    } // startSearching

    fun stop() {
        connectionsClient.stopAdvertising()
        connectionsClient.stopDiscovery()
        connectionsClient.stopAllEndpoints()
        connectedEndpointId = null
        state = DuelConnectionState.IDLE
    } // stop

    fun send(message: DuelMessage) {
        val endpointId = connectedEndpointId ?: return // val endpointId = ... ?: return
        connectionsClient.sendPayload(endpointId, Payload.fromBytes(message.toJson().toByteArray(Charsets.UTF_8)))
    } // send
} // class NetworkManager
