//
//  BluetoothManager.swift
//  CoreDirections
//
//  Created on 5/18/25.
//

import Foundation
import CoreBluetooth

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    // MARK: - Properties
    
    // CoreBluetooth 관련 속성
    private var centralManager: CBCentralManager?
    @Published var discoveredPeripherals: [CBPeripheral] = []
    @Published var connectedPeripheral: CBPeripheral?
    @Published var isScanning: Bool = false
    @Published var isConnected: Bool = false
    
    // 서비스 및 특성 UUID
    private let serviceUUID = CBUUID(string: "180D") // 기본 Heart Rate Service UUID (테스트용)
    private let characteristicUUID = CBUUID(string: "2A37") // 기본 Heart Rate Measurement UUID (테스트용)
    
    // 데이터 전송용 특성
    private var dataCharacteristic: CBCharacteristic?
    
    // MARK: - Initialization
    
    // 지연 초기화 - 권한을 즉시 요청하지 않음
    override init() {
        super.init()
        // 초기화만 하고 centralManager는 실제 스캔 시작할 때 생성
    }
    
    // 실제 CBCentralManager 초기화 (지연 초기화)
    private func initializeCentralManager() {
        guard centralManager == nil else { return }
        
        let options: [String: Any] = [
            CBCentralManagerOptionShowPowerAlertKey: false, // 전원 알림 비활성화
            // 블루투스 사용 권한 대화상자가 표시되는 시점을 제어할 수 있도록 설정
            CBCentralManagerOptionRestoreIdentifierKey: "CoreDirectionsBluetoothManager"
        ]
        
        centralManager = CBCentralManager(delegate: self, queue: nil, options: options)
    }
    
    // MARK: - Public Methods
    
    /// 주변 기기 스캔 시작
    func startScanning() {
        // 중앙 관리자가 초기화되지 않았다면 초기화
        if centralManager == nil {
            initializeCentralManager()
        }
        
        guard let centralManager = centralManager, centralManager.state == .poweredOn else {
            print("Bluetooth is not powered on or not initialized")
            return
        }
        
        discoveredPeripherals.removeAll()
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        isScanning = true
        print("Scanning started")
    }
    
    /// 주변 기기 스캔 중지
    func stopScanning() {
        guard let centralManager = centralManager else { return }
        
        centralManager.stopScan()
        isScanning = false
        print("Scanning stopped")
    }
    
    /// 특정 기기에 연결
    func connect(to peripheral: CBPeripheral) {
        guard let centralManager = centralManager else { return }
        
        centralManager.connect(peripheral, options: nil)
        print("Connecting to \(peripheral.name ?? "Unknown Device")...")
    }
    
    /// 연결 해제
    func disconnect() {
        guard let centralManager = centralManager, let peripheral = connectedPeripheral else { return }
        
        centralManager.cancelPeripheralConnection(peripheral)
        print("Disconnecting from \(peripheral.name ?? "Unknown Device")...")
    }
    
    /// JSON 데이터 전송
    func sendCompassData(_ compassData: CompassData, latitude: Double, longitude: Double, altitude: Double) {
        guard let peripheral = connectedPeripheral,
              let characteristic = dataCharacteristic,
              peripheral.state == .connected else {
            print("Cannot send data: No connected device or characteristic")
            return
        }
        
        // JSON 데이터 생성
        let dataDict: [String: Any] = [
            "magneticHeading": compassData.magneticHeading,
            "trueHeading": compassData.trueHeading,
            "headingDirection": compassData.headingDirection,
            "headingDegrees": compassData.headingDegrees,
            "pitch": compassData.pitch,
            "roll": compassData.roll,
            "yaw": compassData.yaw,
            "latitude": latitude,
            "longitude": longitude,
            "altitude": altitude,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dataDict, options: [])
            
            // 데이터 분할이 필요한 경우를 대비 (BLE 패킷 크기 제한)
            let maxLength = 20 // BLE의 일반적인 MTU 크기 고려 (실제로는 협상될 수 있음)
            let dataLength = jsonData.count
            
            if dataLength <= maxLength {
                // 단일 패킷으로 전송
                peripheral.writeValue(jsonData, for: characteristic, type: .withResponse)
                print("Data sent in single packet: \(jsonData.count) bytes")
            } else {
                // 여러 패킷으로 분할 전송
                var offset = 0
                while offset < dataLength {
                    let length = min(maxLength, dataLength - offset)
                    let chunk = jsonData.subdata(in: offset..<(offset + length))
                    peripheral.writeValue(chunk, for: characteristic, type: .withResponse)
                    offset += length
                }
                print("Data sent in multiple packets: \(dataLength) bytes total")
            }
        } catch {
            print("Failed to serialize JSON data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
        case .poweredOff:
            print("Bluetooth is powered off")
            isConnected = false
            connectedPeripheral = nil
        case .resetting:
            print("Bluetooth is resetting")
        case .unauthorized:
            print("Bluetooth is unauthorized")
        case .unsupported:
            print("Bluetooth is not supported")
        case .unknown:
            print("Bluetooth state is unknown")
        @unknown default:
            print("Unknown Bluetooth state")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // 이미 발견된 기기인지 확인
        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredPeripherals.append(peripheral)
            print("Discovered device: \(peripheral.name ?? "Unknown") - RSSI: \(RSSI)")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "Unknown Device")")
        connectedPeripheral = peripheral
        isConnected = true
        peripheral.delegate = self
        
        // 서비스 검색
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to \(peripheral.name ?? "Unknown Device"): \(error?.localizedDescription ?? "Unknown error")")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from \(peripheral.name ?? "Unknown Device"): \(error?.localizedDescription ?? "No error")")
        connectedPeripheral = nil
        isConnected = false
    }
    // MARK: - CBPeripheralDelegate
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else { return }
        
        for service in services {
            print("Discovered service: \(service.uuid)")
            peripheral.discoverCharacteristics([characteristicUUID], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Error discovering characteristics: \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            print("Discovered characteristic: \(characteristic.uuid)")
            
            if characteristic.uuid == characteristicUUID {
                print("Found target characteristic for data transfer")
                dataCharacteristic = characteristic
                
                // 알림 활성화 (기기가 알림을 지원하는 경우)
                if characteristic.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error updating characteristic value: \(error.localizedDescription)")
            return
        }
        
        // 데이터 수신 처리 (필요한 경우)
        if let data = characteristic.value {
            print("Received data: \(data.count) bytes")
            
            if let stringValue = String(data: data, encoding: .utf8) {
                print("Received string: \(stringValue)")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error writing value to characteristic: \(error.localizedDescription)")
        } else {
            print("Successfully wrote value to characteristic")
        }
    }
}
