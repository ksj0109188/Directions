//
//  BluetoothManager.swift
//  CoreDirections
//
//  Created on 5/18/25.
//

import Foundation
import CoreBluetooth

class BluetoothManager: NSObject, ObservableObject, CBPeripheralManagerDelegate {
    // MARK: - Properties
    
    // CoreBluetooth 관련 속성
    private var peripheralManager: CBPeripheralManager?
    @Published var isAdvertising: Bool = false
    @Published var isConnected: Bool = false
    @Published var connectedCentral: CBCentral?
    
    // 이전 속성(CBCentralManager용)과의 호환성을 위한 더미 속성
    @Published var discoveredPeripherals: [CBPeripheral] = []
    @Published var connectedPeripheral: CBPeripheral?
    @Published var isScanning: Bool = false
    
    // 서비스 및 특성 UUID - 사용자 정의 UUID로 변경
    private let serviceUUID = CBUUID(string: "A1B2C3D4-1234-5678-9ABC-DEF012345678")
    private let characteristicUUID = CBUUID(string: "B1A2C3D4-1234-5678-9ABC-DEF012345678")
    
    // 데이터 전송용 특성
    private var dataCharacteristic: CBMutableCharacteristic?
    private var dataService: CBMutableService?
    
    // 연결된 central 장치들
    @Published var subscribedCentrals: [CBCentral] = []
    
    // MARK: - Initialization
    
    // 지연 초기화 - 권한을 즉시 요청하지 않음
    override init() {
        super.init()
        // 초기화만 하고 peripheralManager는 실제 광고 시작할 때 생성
    }
    
    // 실제 CBPeripheralManager 초기화 (지연 초기화)
    private func initializePeripheralManager() {
        guard peripheralManager == nil else { return }
        
        // 복원 식별자 없이 초기화 (단순화)
        let options: [String: Any] = [
            CBPeripheralManagerOptionShowPowerAlertKey: false // 전원 알림 비활성화
        ]
        
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil, options: options)
    }
    
    // MARK: - Public Methods
    
    /// 광고 시작 (peripheralManager 역할)
    func startAdvertising() {
        // peripheralManager가 초기화되지 않았다면 초기화
        if peripheralManager == nil {
            initializePeripheralManager()
        }
        
        guard let peripheralManager = peripheralManager, peripheralManager.state == .poweredOn else {
            print("Bluetooth is not powered on or not initialized")
            return
        }
        
        // 이미 광고 중이라면 중단
        if isAdvertising {
            peripheralManager.stopAdvertising()
        }
        
        // 서비스 생성
        setupServices()
        
        // 광고 시작
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: "Compass Data"
        ]
        
        peripheralManager.startAdvertising(advertisementData)
        isAdvertising = true
        print("Advertising started")
    }
    
    /// 광고 중지
    func stopAdvertising() {
        guard let peripheralManager = peripheralManager else { return }
        
        peripheralManager.stopAdvertising()
        isAdvertising = false
        print("Advertising stopped")
    }
    
    /// 서비스 및 특성 설정
    private func setupServices() {
        guard let peripheralManager = peripheralManager else { return }
        
        // 기존 서비스 제거
        if let service = dataService {
            peripheralManager.removeAllServices()
        }
        
        // 특성 생성 - 읽기, 쓰기, 알림 권한 부여
        dataCharacteristic = CBMutableCharacteristic(
            type: characteristicUUID,
            properties: [.read, .write, .notify],
            value: nil,
            permissions: [.readable, .writeable]
        )
        
        // 서비스 생성
        dataService = CBMutableService(type: serviceUUID, primary: true)
        
        // 서비스에 특성 추가
        if let characteristic = dataCharacteristic {
            dataService?.characteristics = [characteristic]
        }
        
        // 서비스 추가
        if let service = dataService {
            peripheralManager.add(service)
            print("Service added")
        }
    }
    
    /// JSON 데이터 전송
    func sendCompassData(_ compassData: CompassData, latitude: Double, longitude: Double, altitude: Double) {
        guard let peripheralManager = peripheralManager,
              peripheralManager.state == .poweredOn,
              isAdvertising else {
            // 구독자가 없더라도 광고 중이라면 계속 실행 (구독자가 나타날 것에 대비)
            print("Waiting for subscribers while advertising")
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
            
            // 구독한 central로 데이터 전송 (notify)
            guard let characteristic = dataCharacteristic else {
                print("Characteristic not found")
                return
            }
            
            // 연결된 기기가 있을 때만 실제 전송
            if !subscribedCentrals.isEmpty {
                let success = peripheralManager.updateValue(
                    jsonData,
                    for: characteristic,
                    onSubscribedCentrals: nil // nil = 모든 구독 central에 전송
                )
                
                if success {
                    print("Data successfully sent: \(jsonData.count) bytes")
                } else {
                    print("Failed to send data - will retry when ready")
                    // peripheralManagerIsReady 델리게이트 메서드에서 자동으로 재시도함
                }
            } else {
                // 디버그 목적으로 로그만 남김
                print("Data ready but no subscribers: \(jsonData.count) bytes")
            }
        } catch {
            print("Failed to serialize JSON data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Legacy Methods (for compatibility with previous CBCentralManager implementation)
    
    /// 주변 기기 스캔 시작 (CBCentralManager 호환성 - 실제로는 광고 시작)
    func startScanning() {
        startAdvertising()
        isScanning = isAdvertising // 호환성을 위해 상태 업데이트
    }
    
    /// 주변 기기 스캔 중지 (CBCentralManager 호환성 - 실제로는 광고 중지)
    func stopScanning() {
        stopAdvertising()
        isScanning = isAdvertising // 호환성을 위해 상태 업데이트
    }
    
    /// 특정 기기에 연결 (CBCentralManager 호환성 - 무의미한 더미 메서드)
    func connect(to peripheral: CBPeripheral) {
        print("[Legacy] connect 메서드 호출됨 - 이제 peripheral 관리자로 변경되어 이 작업은 의미가 없습니다.")
    }
    
    /// 연결 해제 (CBCentralManager 호환성 - 무의미한 더미 메서드)
    func disconnect() {
        print("[Legacy] disconnect 메서드 호출됨 - 이제 peripheral 관리자로 변경되어 이 작업은 의미가 없습니다.")
    }
    
    // MARK: - CBPeripheralManagerDelegate
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            print("Bluetooth is powered on")
            // 바로 광고 시작하지 않음 - 사용자가 명시적으로 시작해야 함
        case .poweredOff:
            print("Bluetooth is powered off")
            isAdvertising = false
            isScanning = false // 호환성 위한 상태 업데이트
            isConnected = false
            subscribedCentrals.removeAll()
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
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            print("Error adding service: \(error.localizedDescription)")
        } else {
            print("Service added successfully: \(service.uuid)")
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print("Error starting advertising: \(error.localizedDescription)")
            isAdvertising = false
            isScanning = false // 호환성을 위한 상태 업데이트
        } else {
            print("Advertising started successfully")
            isAdvertising = true
            isScanning = true // 호환성을 위한 상태 업데이트
            
            // 광고가 성공적으로 시작되면 알림 전송
            NotificationCenter.default.post(name: Notification.Name("BluetoothAdvertisingStarted"), object: nil)
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("Central \(central.identifier.uuidString) subscribed to characteristic")
        
        if !subscribedCentrals.contains(where: { $0.identifier == central.identifier }) {
            subscribedCentrals.append(central)
        }
        
        isConnected = !subscribedCentrals.isEmpty
        connectedCentral = subscribedCentrals.first
        
        // 호환성을 위한 상태 업데이트
        if isConnected && connectedPeripheral == nil {
            // 더미 CBPeripheral 객체는 생성할 수 없으므로 그냥 상태만 업데이트
            print("Central connected (compatibility mode)")
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("Central \(central.identifier.uuidString) unsubscribed from characteristic")
        
        subscribedCentrals.removeAll { $0.identifier == central.identifier }
        
        isConnected = !subscribedCentrals.isEmpty
        connectedCentral = subscribedCentrals.first
        
        // 호환성을 위한 상태 업데이트
        if !isConnected {
            connectedPeripheral = nil
        }
    }
    
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        print("Peripheral manager is ready to update subscribers")
        // 여기서 보내지 못한 큐에 있는 데이터를 전송할 수 있음
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        // 데이터 읽기 요청 처리
        if request.characteristic.uuid == characteristicUUID {
            // 빈 데이터 전송
            request.value = "{}".data(using: .utf8)
            peripheral.respond(to: request, withResult: .success)
        } else {
            peripheral.respond(to: request, withResult: .attributeNotFound)
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        // 데이터 쓰기 요청 처리 (필요한 경우)
        for request in requests {
            if request.characteristic.uuid == characteristicUUID,
               let value = request.value {
                print("Received write request with value: \(value.count) bytes")
                // 여기서 수신된 데이터를 처리할 수 있음
            }
        }
        
        peripheral.respond(to: requests[0], withResult: .success)
    }
}
