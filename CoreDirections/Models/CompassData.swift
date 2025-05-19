//
//  CompassData.swift
//  CoreDirections
//
//  Created on 5/18/25.
//

import Foundation
import CoreLocation

struct CompassData {
    // 방위각 (도 단위)
    let magneticHeading: Double
    let trueHeading: Double
    
    // 기기 기울기 정보
    let pitch: Double
    let roll: Double
    let yaw: Double
    
    // 방위각 문자열 표현 (북, 북동, 동, 남동, 남, 남서, 서, 북서)
    var headingDirection: String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int(((trueHeading < 0 ? trueHeading + 360 : trueHeading) + 22.5) / 45) % 8
        return directions[index]
    }
    
    // 방위각 숫자 표현
    var headingDegrees: String {
        return String(format: "%.0f°", trueHeading)
    }
    
    // 수평 여부 (기기가 평평하게 놓여있는지)
    var isDeviceFlat: Bool {
        return abs(pitch) < 10 && abs(roll) < 10
    }
    
    // 초기값
    static var initial: CompassData {
        return CompassData(magneticHeading: 0, trueHeading: 0, pitch: 0, roll: 0, yaw: 0)
    }
}
