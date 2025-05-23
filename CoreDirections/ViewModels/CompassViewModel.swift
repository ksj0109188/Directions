//
//  CompassViewModel.swift
//  CoreDirections
//
//  Created on 5/18/25.
//

import Foundation
import CoreLocation
import CoreMotion
import Combine
import SwiftUI
import CoreBluetooth

class CompassViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    // 나침반 데이터
    @Published var compassData: CompassData = .initial
    
    // 위치 관리자
    private let locationManager = CLLocationManager()
    
    // 모션 관리자
    private let motionManager = CMMotionManager()
    
    // 아두이노 블루투스 관리자 (Central 역할)
    @Published var arduinoBluetoothManager = ArduinoBluetoothManager()
    
    // 위도 및 경도
    @Published var latitude: Double = 0
    @Published var longitude: Double = 0
    
    // 고도
    @Published var altitude: Double = 0
    
    // 기기의 현재 주소
    @Published var currentAddress: String = "위치 정보를 가져오는 중..."
    
    // 보정 필요 여부
    @Published var needsCalibration: Bool = false
    
    // 위치 접근 허용 여부
    @Published var isAuthorized: Bool = false
    
    // 데이터 전송 활성화 여부
    @Published var isDataTransmissionEnabled: Bool = false
    
    // 데이터 전송 타이머
    private var transmissionTimer: Timer?
    
    // 지오코더
    private let geocoder = CLGeocoder()
    
    // 서비스 초기화 여부 상태값
    @Published var isLocationServicesInitialized: Bool = false
    @Published var isMotionServicesInitialized: Bool = false
    
    override init() {
        super.init()
        
        // 위치 관리자 설정 - 하지만 권한 요청은 아직 하지 않음
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // 현재 권한 상태 확인
        checkLocationAuthorizationStatus()
        
        // ArduinoBluetoothManager 상태 관찰
        setupBluetoothObservers()
        
        // 블루투스 연결 알림 등록
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(bluetoothConnected),
            name: Notification.Name("ArduinoBluetoothConnected"),
            object: nil
        )
    }
    
    deinit {
        stopLocationServices()
        stopMotionServices()
        stopDataTransmission()
        NotificationCenter.default.removeObserver(self)
    }
    
    // 블루투스가 연결되면 자동으로 데이터 전송 시작
    @objc private func bluetoothConnected() {
        print("Arduino bluetooth connected, beginning data transmission")
        startDataTransmission()
    }
    
    // 위치 서비스 권한 상태 확인
    private func checkLocationAuthorizationStatus() {
        if #available(iOS 14.0, *) {
            switch locationManager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                isAuthorized = true
            default:
                isAuthorized = false
            }
        } else {
            switch CLLocationManager.authorizationStatus() {
            case .authorizedWhenInUse, .authorizedAlways:
                isAuthorized = true
            default:
                isAuthorized = false
            }
        }
    }
    
    // 위치 서비스 시작 - 사용자가 명시적으로 시작할 때 호출
    func startLocationServices() {
        // 이미 초기화되었다면 다시 시작하지 않음
        if isLocationServicesInitialized {
            return
        }
        
        // 위치 권한 요청
        locationManager.requestWhenInUseAuthorization()
        
        // 위치 업데이트 시작
        locationManager.startUpdatingLocation()
        
        // 나침반 업데이트 시작
        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        }
        
        isLocationServicesInitialized = true
    }
    
    // 모션 서비스 시작
    func startMotionServices() {
        // 이미 초기화되었다면 다시 시작하지 않음
        if isMotionServicesInitialized {
            return
        }
        
        // 모션 업데이트 시작
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.1
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (data, error) in
                guard let self = self, let data = data else { return }
                
                // 기울기 정보 업데이트
                let pitch = data.attitude.pitch * 180 / .pi
                let roll = data.attitude.roll * 180 / .pi
                let yaw = data.attitude.yaw * 180 / .pi
                
                // compassData 업데이트
                DispatchQueue.main.async {
                    self.compassData = CompassData(
                        magneticHeading: self.compassData.magneticHeading,
                        trueHeading: self.compassData.trueHeading,
                        pitch: pitch,
                        roll: roll,
                        yaw: yaw
                    )
                }
            }
            
            isMotionServicesInitialized = true
        }
    }
    
    // 위치 서비스 중지
    func stopLocationServices() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        isLocationServicesInitialized = false
    }
    
    // 모션 서비스 중지
    func stopMotionServices() {
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
        isMotionServicesInitialized = false
    }
    
    // ArduinoBluetoothManager 상태 관찰 설정
    private func setupBluetoothObservers() {
        // 연결 상태에 따라 데이터 전송 시작/중지
        arduinoBluetoothManager.$isConnected
            .sink { [weak self] isConnected in
                guard let self = self else { return }
                
                if isConnected && self.isDataTransmissionEnabled {
                    self.startDataTransmission()
                } else if !isConnected {
                    self.stopDataTransmission()
                }
            }
            .store(in: &cancellables)
    }
    
    // 데이터 전송 관련 Cancellable 저장
    private var cancellables = Set<AnyCancellable>()
    
    // 아두이노 블루투스 스캔 시작 - 사용자가 명시적으로 블루투스 기능을 시작할 때 호출
    func startBluetoothScanning() {
        arduinoBluetoothManager.startScanning()
    }
    
    // 데이터 전송 시작
    func startDataTransmission() {
        // 아두이노가 연결되어 있는지 확인
        if !arduinoBluetoothManager.isConnected {
            print("아두이노에 먼저 연결하세요")
            return
        }
        
        isDataTransmissionEnabled = true
        
        // 이미 실행 중인 타이머가 있다면 중지
        stopDataTransmission()
        
        // 0.2초마다 데이터 전송 (더 자주 전송)
        transmissionTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.sendCurrentDataViaBluetooth()
        }
        
        // 첫 데이터는 즉시 전송
        sendCurrentDataViaBluetooth()
        
        print("Data transmission started with high frequency")
    }
    
    // 데이터 전송 중지
    func stopDataTransmission() {
        transmissionTimer?.invalidate()
        transmissionTimer = nil
        
        if isDataTransmissionEnabled {
            isDataTransmissionEnabled = false
            print("Data transmission stopped")
        }
    }
    
    // 현재 데이터를 블루투스로 전송
    private func sendCurrentDataViaBluetooth() {
        arduinoBluetoothManager.sendCompassData(
            compassData,
            latitude: latitude,
            longitude: longitude,
            altitude: altitude
        )
    }
    
    // 위치 권한 상태 업데이트
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if #available(iOS 14.0, *) {
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                isAuthorized = true
                // 권한이 허용되면 서비스 시작
                if !isLocationServicesInitialized {
                    startLocationServices()
                }
                if !isMotionServicesInitialized {
                    startMotionServices()
                }
            default:
                isAuthorized = false
            }
        }
    }
    
    // iOS 14 미만 호환
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            isAuthorized = true
            // 권한이 허용되면 서비스 시작
            if !isLocationServicesInitialized {
                startLocationServices()
            }
            if !isMotionServicesInitialized {
                startMotionServices()
            }
        default:
            isAuthorized = false
        }
    }
    
    // 나침반 방향 업데이트
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // CompassData 업데이트
            self.compassData = CompassData(
                magneticHeading: newHeading.magneticHeading,
                trueHeading: newHeading.trueHeading,
                pitch: self.compassData.pitch,
                roll: self.compassData.roll,
                yaw: self.compassData.yaw
            )
        }
    }
    
    // 위치 업데이트
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.latitude = location.coordinate.latitude
            self.longitude = location.coordinate.longitude
            self.altitude = location.altitude
            
            // 제한된 간격으로만 주소 변환 요청 (위치가 크게 변했거나 일정 시간이 지났을 때만)
            self.throttledGeocodeRequest(for: location)
            
            // 데이터 전송은 계속 유지 (제한 없이)
            if self.isDataTransmissionEnabled && self.arduinoBluetoothManager.isConnected {
                self.sendCurrentDataViaBluetooth()
            }
        }
    }
    
    // 마지막 주소 변환 요청 시간과 위치
    private var lastGeocodingTime: Date = Date(timeIntervalSince1970: 0)
    private var lastGeocodedLocation: CLLocation?
    private let geocodingMinInterval: TimeInterval = 5.0 // 최소 5초 간격
    private let geocodingMinDistance: CLLocationDistance = 50.0 // 최소 50미터 이동
    
    // 제한된 간격으로 Geocoding 요청 (주소 변환만 제한)
    private func throttledGeocodeRequest(for location: CLLocation) {
        let now = Date()
        let timeSinceLastRequest = now.timeIntervalSince(lastGeocodingTime)
        
        var shouldRequestNewAddress = false
        
        // 마지막 요청으로부터 최소 간격이 지났는지 확인
        if timeSinceLastRequest > geocodingMinInterval {
            shouldRequestNewAddress = true
        }
        
        // 일정 거리 이상 이동했는지 확인 (첫 요청이거나 거리 계산 가능할 때만)
        if let lastLocation = lastGeocodedLocation {
            let distance = location.distance(from: lastLocation)
            if distance > geocodingMinDistance {
                shouldRequestNewAddress = true
            }
        } else {
            // 첫 요청인 경우
            shouldRequestNewAddress = true
        }
        
        if shouldRequestNewAddress {
            lastGeocodingTime = now
            lastGeocodedLocation = location
            getAddressFromLocation(location)
        }
    }
    
    // 위치를 주소로 변환하는 함수
    private func getAddressFromLocation(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] (placemarks, error) in
            guard let self = self, error == nil, let placemark = placemarks?.first else {
                self?.currentAddress = "주소를 가져올 수 없습니다"
                return
            }
            
            let address = [
                placemark.locality,
                placemark.administrativeArea,
                placemark.country
            ].compactMap { $0 }.joined(separator: ", ")
            
            self.currentAddress = address.isEmpty ? "주소를 찾을 수 없습니다" : address
        }
    }
    
    // 보정 필요 여부
    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        needsCalibration = true
        return true
    }
}
