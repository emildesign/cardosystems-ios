// ConnectionState.swift
public enum ConnectionState: Equatable {
    case idle
    case connecting
    case connected(deviceId: String)
    case disconnecting
    case failed(DisconnectReason)
}
