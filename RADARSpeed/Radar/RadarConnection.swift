import CoreBluetooth
import Foundation
import Observation

/// Finds, connects to and streams from one Garmin Varia radar.
///
/// Delegate callbacks arrive on the main queue. Every characteristic the radar service
/// offers is subscribed to (notify) or read once (read) and reported through `onEvent`,
/// so Phase 0 captures show whatever the hardware actually sends — including anything
/// beyond `3203`.
@Observable
final class RadarConnection: NSObject {
    enum State: Equatable {
        case idle, unavailable(String), scanning, connecting(String), connected(String)
    }

    enum Event {
        case log(String)
        case value(characteristic: CBUUID, Data)
    }

    static let radarService = CBUUID(string: "6A4E3200-667B-11E3-949A-0800200C9A66")
    static let radarData = CBUUID(string: "6A4E3203-667B-11E3-949A-0800200C9A66")
    static let batteryService = CBUUID(string: "180F")
    static let batteryLevel = CBUUID(string: "2A19")

    private(set) var state: State = .idle
    private(set) var batteryPercent: Int?

    /// Every BLE happening worth logging, in arrival order.
    @ObservationIgnored var onEvent: (Event) -> Void = { _ in }

    @ObservationIgnored private var central: CBCentralManager!
    @ObservationIgnored private var peripheral: CBPeripheral?
    private static let rememberedKey = "rememberedRadarID"

    func start() {
        guard central == nil else { return }
        central = CBCentralManager(delegate: self, queue: nil)
    }

    private func connectOrScan() {
        if let idString = UserDefaults.standard.string(forKey: Self.rememberedKey),
           let id = UUID(uuidString: idString),
           let known = central.retrievePeripherals(withIdentifiers: [id]).first {
            onEvent(.log("connecting to remembered radar \(id)"))
            connect(known)
        } else {
            state = .scanning
            onEvent(.log("scanning"))
            central.scanForPeripherals(withServices: [Self.radarService])
        }
    }

    private func connect(_ peripheral: CBPeripheral) {
        self.peripheral = peripheral
        peripheral.delegate = self
        state = .connecting(peripheral.name ?? "Radar")
        // No timeout: a pending connect completes whenever the radar comes into range.
        central.connect(peripheral)
    }
}

extension RadarConnection: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: connectOrScan()
        case .unauthorized: state = .unavailable("Bluetooth permission denied")
        case .poweredOff: state = .unavailable("Bluetooth is off")
        case .unsupported: state = .unavailable("Bluetooth unsupported")
        default: state = .unavailable("Bluetooth not ready")
        }
        onEvent(.log("central state \(central.state.rawValue)"))
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        onEvent(.log("discovered \(peripheral.name ?? "?") \(peripheral.identifier) rssi \(RSSI)"))
        central.stopScan()
        connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: Self.rememberedKey)
        state = .connected(peripheral.name ?? "Radar")
        onEvent(.log("connected \(peripheral.name ?? "?")"))
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        onEvent(.log("failed to connect: \(error?.localizedDescription ?? "unknown")"))
        connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral,
                        timestamp: CFAbsoluteTime, isReconnecting: Bool, error: (any Error)?) {
        batteryPercent = nil
        onEvent(.log("disconnected: \(error?.localizedDescription ?? "no error")"))
        if !isReconnecting { connect(peripheral) }
    }
}

extension RadarConnection: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        for service in peripheral.services ?? [] {
            onEvent(.log("service \(service.uuid)"))
            if service.uuid == Self.radarService || service.uuid == Self.batteryService {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?) {
        for characteristic in service.characteristics ?? [] {
            let properties = characteristic.properties
            onEvent(.log("characteristic \(characteristic.uuid) properties 0x\(String(properties.rawValue, radix: 16))"))
            if properties.contains(.read) { peripheral.readValue(for: characteristic) }
            if properties.contains(.notify) || properties.contains(.indicate) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: (any Error)?) {
        onEvent(.log("notify \(characteristic.uuid) \(characteristic.isNotifying) \(error?.localizedDescription ?? "")"))
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        guard let value = characteristic.value else { return }
        if characteristic.uuid == Self.batteryLevel, let level = value.first, level <= 100 {
            batteryPercent = Int(level)
        }
        onEvent(.value(characteristic: characteristic.uuid, value))
    }
}
