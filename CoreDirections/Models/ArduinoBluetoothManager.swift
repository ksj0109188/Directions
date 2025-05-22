//
//  ArduinoBluetoothManager.swift
//  CoreDirections
//
//  Created on 5/22/25.
//

import Foundation
import CoreBluetooth
import Combine

/// 아두이노와 통신하기 위한 Central 블루투스 매니저
class ArduinoBluetoothManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var discoveredPeripherals: [CBPeripheral] = []
    @Published var connectedPeripheral: CBPeripheral?
    @Published var isScanning: Bool = false
    @Published var isConnected: Bool = false
    @Published var statusMessage: String = "초기화 중..."
    @Published var connectionStrength: Int = 0 // RSSI 기반 연결 강도 (-100 ~ 0)
    
    // 아두이노 제어 관련
    @Published var lastSentCommand: String = ""
    @Published var commandsSent: Int = 0
    
    // MARK: - Private Properties
    private var centralManager: CBCentralManager!
    private var writeCharacteristic: CBCharacteristic?
    
    // 범용 BLE 통신을 위한 변수들
    private var availableServices: [CBUUID] = []
    private var availableCharacteristics: [CBCharacteristic] = []
    private var readCharacteristic: CBCharacteristic?
    
    // 자동 재연결 타이머
    private var reconnectTimer: Timer?
    private var rssiTimer: Timer?
    
    // MARK: - Initialization
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    deinit {
        stopScanning()
        disconnect()
        reconnectTimer?.invalidate()
        rssiTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// 스캔 시작 - 모든 BLE 기기 탐색 (LightBlue 방식)
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            statusMessage = "블루투스가 꺼져있습니다"
            return
        }
        
        statusMessage = "주변 BLE 기기 탐색 중..."
        isScanning = true
        discoveredPeripherals.removeAll()
        
        // 모든 BLE 기기 탐색 (서비스 필터 없음)
        centralManager.scanForPeripherals(
            withServices: nil, // nil = 모든 기기 탐색
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        
        // 15초 후 스캔 중지
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            if self.isScanning {
                self.stopScanning()
                if self.discoveredPeripherals.isEmpty {
                    self.statusMessage = "BLE 기기를 찾을 수 없습니다"
                }
            }
        }
    }
    
    /// 스캔 중지
    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        if !isConnected {
            statusMessage = "스캔 중지됨"
        }
    }
    
    /// 특정 기기에 연결
    func connect(to peripheral: CBPeripheral) {
        stopScanning()
        statusMessage = "연결 중..."
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }
    
    /// 자동으로 첫 번째 발견된 기기에 연결
    func connectToFirstDevice() {
        guard let firstPeripheral = discoveredPeripherals.first else {
            statusMessage = "연결할 기기가 없습니다"
            return
        }
        connect(to: firstPeripheral)
    }
    
    /// 연결 해제
    func disconnect() {
        guard let peripheral = connectedPeripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
        stopRSSIMonitoring()
    }
    
    /// 아두이노에 명령 전송
    func sendCommand(_ command: String) {
        guard let peripheral = connectedPeripheral,
              let characteristic = writeCharacteristic,
              let data = command.data(using: .utf8) else {
            print("전송 조건이 준비되지 않았습니다")
            statusMessage = "전송 실패: 연결되지 않음"
            return
        }
        
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        lastSentCommand = command
        commandsSent += 1
        
        print("아두이노에 명령 전송: '\(command)'")
        statusMessage = "명령 전송: \(command)"
    }
    
    // 모터 제어 명령들 제거 - 나침반/위치 데이터만 전송
    
    /// 나침반 데이터 JSON 형태로 전송 (아두이노가 파싱 가능하도록)
    func sendCompassData(_ compassData: CompassData, latitude: Double, longitude: Double, altitude: Double) {
        let jsonString = createCompassJSON(compassData, latitude: latitude, longitude: longitude, altitude: altitude)
        sendCommand(jsonString)
    }
    
    /// 간단한 방위각만 전송 (필요시 사용)
    func sendAzimuthOnly(_ heading: Double) {
        let azimuthCommand = String(format: "%.1f", heading)
        sendCommand(azimuthCommand)
    }
    
    // MARK: - Private Methods
    
    /// 나침반 데이터를 JSON 문자열로 변환
    private func createCompassJSON(_ compassData: CompassData, latitude: Double, longitude: Double, altitude: Double) -> String {
        let jsonDict: [String: Any] = [
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
            let jsonData = try JSONSerialization.data(withJSONObject: jsonDict, options: .fragmentsAllowed)
            return String(data: jsonData, encoding: .utf8) ?? "error"
        } catch {
            print("JSON 직렬화 실패: \(error)")
            return "error"
        }
    }
    
    /// RSSI 모니터링 시작
    private func startRSSIMonitoring() {
        rssiTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.connectedPeripheral?.readRSSI()
        }
    }
    
    /// RSSI 모니터링 중지
    private func stopRSSIMonitoring() {
        rssiTimer?.invalidate()
        rssiTimer = nil
        connectionStrength = 0
    }
    
    /// 사용 가능한 특성들 출력
    private func printAvailableCharacteristics() {
        print("\n=== 사용 가능한 BLE 특성들 ===")
        for (index, characteristic) in availableCharacteristics.enumerated() {
            var properties: [String] = []
            if characteristic.properties.contains(.read) { properties.append("Read") }
            if characteristic.properties.contains(.write) { properties.append("Write") }
            if characteristic.properties.contains(.writeWithoutResponse) { properties.append("WriteWithoutResponse") }
            if characteristic.properties.contains(.notify) { properties.append("Notify") }
            if characteristic.properties.contains(.indicate) { properties.append("Indicate") }
            
            print("\(index + 1). UUID: \(characteristic.uuid)")
            print("   Properties: \(properties.joined(separator: ", "))")
        }
        print("==============================\n")
    }
    
    /// 특정 인덱스의 특성으로 데이터 전송 (디버깅용)
    func sendDataToCharacteristic(at index: Int, data: String) {
        guard index < availableCharacteristics.count else {
            print("잘못된 특성 인덱스: \(index)")
            return
        }
        
        let characteristic = availableCharacteristics[index]
        guard let peripheral = connectedPeripheral,
              let data = data.data(using: .utf8) else { return }
        
        if characteristic.properties.contains(.write) {
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
            print("데이터 전송 (withResponse): \(data) → \(characteristic.uuid)")
        } else if characteristic.properties.contains(.writeWithoutResponse) {
            peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
            print("데이터 전송 (withoutResponse): \(data) → \(characteristic.uuid)")
        } else {
            print("이 특성은 쓰기를 지원하지 않습니다: \(characteristic.uuid)")
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension ArduinoBluetoothManager: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            statusMessage = "블루투스 준비됨"
            print("블루투스가 켜졌습니다")
        case .poweredOff:
            statusMessage = "블루투스가 꺼져있습니다"
            isScanning = false
            isConnected = false
        case .unauthorized:
            statusMessage = "블루투스 권한이 없습니다"
        case .unsupported:
            statusMessage = "블루투스를 지원하지 않습니다"
        case .resetting:
            statusMessage = "블루투스 재설정 중..."
        case .unknown:
            statusMessage = "블루투스 상태 불명"
        @unknown default:
            statusMessage = "알 수 없는 블루투스 상태"
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        // 이미 발견된 기기인지 확인
        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredPeripherals.append(peripheral)
            
            let deviceName = peripheral.name ?? "Unknown Device"
            print("BLE 기기 발견: \(deviceName) (RSSI: \(RSSI))")
            
            statusMessage = "기기 발견: \(deviceName)"
            
            // "거북이" 이름의 기기를 찾으면 자동 연결
            if deviceName.contains("거북이") || deviceName.contains("turtle") {
                print("아두이노 기기 발견 - 자동 연결 시도")
                connect(to: peripheral)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("BLE 기기에 연결됨: \(peripheral.name ?? "Unknown")")
        
        connectedPeripheral = peripheral
        isConnected = true
        statusMessage = "연결됨: \(peripheral.name ?? "Unknown Device")"
        
        stopScanning()
        
        // 모든 서비스 탐색 (서비스 필터 없음)
        peripheral.discoverServices(nil)
        
        // RSSI 모니터링 시작
        startRSSIMonitoring()
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("연결 실패: \(error?.localizedDescription ?? "알 수 없는 오류")")
        statusMessage = "연결 실패"
        
        // 3초 후 재시도
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.attemptReconnection()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("연결 해제됨: \(error?.localizedDescription ?? "정상 해제")")
        
        connectedPeripheral = nil
        isConnected = false
        writeCharacteristic = nil
        statusMessage = "연결 해제됨"
        
        stopRSSIMonitoring()
        
        // 예상치 못한 연결 해제인 경우 자동 재연결 시도
        if error != nil {
            attemptReconnection()
        }
    }
}


// MARK: - CBPeripheralDelegate
extension ArduinoBluetoothManager: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print("서비스 탐색 실패: \(error!.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else { return }
        
        // 발견된 모든 서비스 저장
        availableServices = services.map { $0.uuid }
        
        for service in services {
            print("서비스 발견: \(service.uuid)")
            
            // 모든 서비스의 특성 탐색
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print("특성 탐색 실패: \(error!.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        
        // 발견된 모든 특성 저장
        availableCharacteristics.append(contentsOf: characteristics)
        
        for characteristic in characteristics {
            print("특성 발견: \(characteristic.uuid) - Properties: \(characteristic.properties)")
            
            // Write 가능한 특성을 찾아서 설정
            if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                if writeCharacteristic == nil {
                    writeCharacteristic = characteristic
                    print("쓰기 특성 설정: \(characteristic.uuid)")
                    statusMessage = "연결 완료 - 데이터 전송 가능"
                }
            }
            
            // Read/Notify 가능한 특성 설정
            if characteristic.properties.contains(.read) || characteristic.properties.contains(.notify) {
                if readCharacteristic == nil {
                    readCharacteristic = characteristic
                    print("읽기 특성 설정: \(characteristic.uuid)")
                }
                
                // 알림 활성화
                if characteristic.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: characteristic)
                    print("알림 활성화: \(characteristic.uuid)")
                }
            }
        }
        
        // 사용 가능한 특성들 로그 출력
        printAvailableCharacteristics()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("특성 값 업데이트 실패: \(error!.localizedDescription)")
            return
        }
        
        if let data = characteristic.value, let receivedString = String(data: data, encoding: .utf8) {
            print("아두이노로부터 데이터 수신: \(receivedString)")
            // 여기서 아두이노에서 받은 데이터를 처리할 수 있습니다
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("데이터 전송 실패: \(error.localizedDescription)")
            statusMessage = "전송 실패: \(error.localizedDescription)"
        } else {
            print("데이터 전송 성공")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if error == nil {
            connectionStrength = RSSI.intValue
            print("연결 강도: \(RSSI.intValue) dBm")
        }
    }
    
    /// 자동 재연결 시도
    private func attemptReconnection() {
        guard !isConnected else { return }
        
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.startScanning()
        }
    }
}
