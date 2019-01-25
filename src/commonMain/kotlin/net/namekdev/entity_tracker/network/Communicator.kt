package net.namekdev.entity_tracker.network

/**
 * Defines basics of network protocol for communication between EntityTracker Manager and UI.
 *
 * @author Namek
 */
abstract class Communicator : RawConnectionCommunicator {
    protected var output: RawConnectionOutputListener? = null

    override fun connected(identifier: String, output: RawConnectionOutputListener) {
        this.output = output
    }

    override fun disconnected() {}


    companion object {

        // tracker events
        const val TYPE_ADDED_ENTITY_SYSTEM: Byte = 60
        const val TYPE_ADDED_MANAGER: Byte = 61
        const val TYPE_ADDED_COMPONENT_TYPE: Byte = 63
        const val TYPE_UPDATED_ENTITY_SYSTEM: Byte = 64
        const val TYPE_ADDED_ENTITY: Byte = 68
        const val TYPE_DELETED_ENTITY: Byte = 73
        const val TYPE_UPDATED_COMPONENT_STATE: Byte = 104

        // UI requests
        const val TYPE_SET_SYSTEM_STATE: Byte = 90
        const val TYPE_SET_MANAGER_STATE: Byte = 94
        const val TYPE_REQUEST_COMPONENT_STATE: Byte = 103
        const val TYPE_SET_COMPONENT_FIELD_VALUE: Byte = 113
        const val TYPE_SET_COMPONENT_STATE_WATCHER: Byte = 117
    }
}
