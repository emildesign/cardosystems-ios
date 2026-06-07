// TransportEvent.swift
enum TransportEvent {
    case connected
    case disconnected(DisconnectReason)
    case dataUpdate(DeviceData)
}
