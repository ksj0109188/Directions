//
//  CoreDirectionsApp.swift
//  CoreDirections
//
//  Created by 김성준 on 5/15/25.
//

import SwiftUI
import CoreMotion
import CoreLocation

@main
struct CoreDirectionsApp: App {
    // ViewModel 인스턴스를 앱 수준에서 생성
    @StateObject private var compassViewModel = CompassViewModel()
    
    init() {
        // Info.plist에 NSLocationWhenInUseUsageDescription 항목이 없어도
        // 사용자에게 권한 요청 메시지를 보여주기 위한 설정
        let locationManager = CLLocationManager()
        locationManager.requestWhenInUseAuthorization()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(compassViewModel)
        }
    }
}
