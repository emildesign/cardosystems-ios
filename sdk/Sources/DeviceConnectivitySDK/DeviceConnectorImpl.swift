import Foundation

/**
 Core SDK implementation.

 Mirrors `com.emildesign.sdk.DeviceConnectorImpl`.
 */
final class DeviceConnectorImpl: DeviceConnector {

    private let transport: DeviceTransport
    private let volumeMutex = NSLock()
    private let internalQueue = DispatchQueue(label: "com.emildesign.sdk.DeviceConnectorImpl")
    private var storedDeviceId: String?

    // Snapshot-based state (mirrors Kotlin StateFlow.value).
    private var stateValue: ConnectionState = .idle {
        didSet { stateContinuation?.yield(stateValue) }
    }
    private var dataValue: DeviceData? {
        didSet { dataContinuation?.yield(dataValue) }
    }

    private var stateContinuation: AsyncStream<ConnectionState>.Continuation?
    private var dataContinuation: AsyncStream<DeviceData?>.Continuation?

    private lazy var stateStream: AsyncStream<ConnectionState> = {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            self.stateContinuation = continuation
            continuation.yield(self.stateValue)
        }
    }()

    private lazy var dataStream: AsyncStream<DeviceData?> = {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            self.dataContinuation = continuation
            continuation.yield(self.dataValue)
        }
    }()

    var connectionState: AsyncStream<ConnectionState> { stateStream }
    var deviceData: AsyncStream<DeviceData?> { dataStream }

    var currentConnectionState: ConnectionState { internalQueue.sync { stateValue } }
    var currentDeviceData: DeviceData? { internalQueue.sync { dataValue } }

    private var eventListenerTask: Task<Void, Never>?

    init(transport: DeviceTransport) {
        self.transport = transport
    }

    // ---- Public API ----

    func connect(deviceId: String) async {
        let shouldProceed: Bool = internalQueue.sync {
            switch stateValue {
            case .connecting, .connected: return false
            default:
                storedDeviceId = deviceId
                stateValue = .connecting
                return true
            }
        }
        guard shouldProceed else { return }
        startListeningToTransport()
        await transport.connect(deviceId: deviceId)
    }

    func disconnect() async {
        let shouldProceed: Bool = internalQueue.sync {
            switch stateValue {
            case .idle, .failed: return false
            default:
                stateValue = .disconnecting
                return true
            }
        }
        guard shouldProceed else { return }
        await transport.disconnect()
    }

    func setVolume(_ level: Int) async -> Result<Void, Error> {
        let isConnected: Bool = internalQueue.sync {
            if case .connected = stateValue { return true } else { return false }
        }
        guard isConnected else {
            return .failure(
                NSError(
                    domain: "DeviceConnectivitySDK",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "setVolume called while not Connected. Current state: \(currentConnectionState)"]
                )
            )
        }
        volumeMutex.lock()
        defer { volumeMutex.unlock() }
        await transport.sendCommand(.setVolume(level: level))
        return .success(())
    }

    func release() {
        Task { [weak self] in
            await self?.disconnect()
            self?.eventListenerTask?.cancel()
        }
    }

    // ---- Private ----

    private func startListeningToTransport() {
        eventListenerTask?.cancel()
        let transport = self.transport
        eventListenerTask = Task { [weak self] in
            for await event in transport.events {
                self?.handleTransportEvent(event)
                if Task.isCancelled { break }
            }
        }
    }

    private func handleTransportEvent(_ event: TransportEvent) {
        switch event {
        case .connected:
            let deviceId: String = internalQueue.sync {
                storedDeviceId ?? "unknown"
            }
            internalQueue.sync { stateValue = .connected(deviceId: deviceId) }
        case .disconnected(let reason):
            switch reason {
            case .consumerDisconnected:
                internalQueue.sync {
                    stateValue = .idle
                    dataValue = nil
                }
                eventListenerTask?.cancel()
            default:
                internalQueue.sync {
                    stateValue = .failed(reason: reason)
                    dataValue = nil
                }
                eventListenerTask?.cancel()
            }
        case .dataUpdate(let data):
            let isConnected: Bool = internalQueue.sync {
                if case .connected = stateValue { return true } else { return false }
            }
            if isConnected {
                internalQueue.sync { dataValue = data }
            }
        }
    }
}
