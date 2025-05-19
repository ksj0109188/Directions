//
//  CompassView.swift
//  CoreDirections
//
//  Created on 5/18/25.
//

import SwiftUI

struct CompassView: View {
    @ObservedObject var viewModel: CompassViewModel
    
    @State private var isFindBluetooth: Bool = false
    
    // 메인 나침반 크기 계산을 위한 환경변수
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var compassSize: CGFloat {
        horizontalSizeClass == .compact ? 280 : 350
    }
    
    var body: some View {
            VStack {
                if !viewModel.isAuthorized {
                    LocationPermissionView()
                } else {
                    VStack(spacing: 20) {
                        // 방위 정보 헤더
                        HStack {
                            VStack(alignment: .leading) {
                                Text(viewModel.compassData.headingDirection)
                                    .font(.system(size: 32, weight: .bold))
                                Text(viewModel.compassData.headingDegrees)
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // 위치 정보
                            VStack(alignment: .trailing) {
                                Text(String(format: "%.5f° N, %.5f° E", viewModel.latitude, viewModel.longitude))
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.secondary)
                                Text(viewModel.currentAddress)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                        
                        Button {
                            isFindBluetooth.toggle()
                        } label: {
                            Text("기기찾기")
                        }

                        // 나침반
                        ZStack {
                            // 외부 원
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                .frame(width: compassSize, height: compassSize)
                            
                            // 나침반 눈금
                            CompassMarkingsView(size: compassSize)
                                .rotationEffect(Angle(degrees: -viewModel.compassData.trueHeading))
                            
                            // 가운데 십자선
                            CompassCrosshairView()
                                .frame(width: compassSize * 0.1, height: compassSize * 0.1)
                            
                            // 방향 표시기 (삼각형)
                            Triangle()
                                .fill(Color.red)
                                .frame(width: 20, height: 20)
                                .offset(y: -(compassSize / 2) )
                            
                            // 경사계 표시 (휴대폰이 수평이 아닐 때)
                            if !viewModel.compassData.isDeviceFlat {
                                Text("기기를 수평으로 유지해주세요")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .padding(8)
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(8)
                                    .offset(y: compassSize / 3)
                            }
                        }
                        .padding()
                        
                        Spacer()
                        
                        // 고도 정보
                        HStack {
                            Label {
                                Text(String(format: "고도: %.1f m", viewModel.altitude))
                                    .font(.system(size: 16))
                            } icon: {
                                Image(systemName: "arrow.up.right")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(10)
                        
                        // 보정 필요 시 안내 메시지
                        if viewModel.needsCalibration {
                            Text("보정이 필요합니다. 8자 모양으로 기기를 움직여주세요.")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding()
                        }
                    }
                    .padding(.vertical)
                }
            }
        .sheet(isPresented: $isFindBluetooth) {
            BluetoothView(bluetoothManager: BluetoothManager())
        }
    }
}

// 나침반 눈금 뷰
struct CompassMarkingsView: View {
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // 주요 방향 (N, E, S, W)
            ForEach(0..<4) { i in
                CompassDirectionView(direction: ["N", "E", "S", "W"][i], size: size)
                    .rotationEffect(Angle(degrees: Double(i) * 90))
            }
            
            // 부방향 (NE, SE, SW, NW)
            ForEach(0..<4) { i in
                CompassDirectionView(direction: ["NE", "SE", "SW", "NW"][i], size: size, isMainDirection: false)
                    .rotationEffect(Angle(degrees: Double(i) * 90 + 45))
            }
            
            // 작은 눈금 (5도 간격)
            ForEach(0..<72) { i in
                Rectangle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: i % 3 == 0 ? 1.5 : 0.5, height: i % 3 == 0 ? 10 : 5)
                    .offset(y: -(size / 2) + 15)
                    .rotationEffect(Angle(degrees: Double(i) * 5))
            }
            
            //TODO: 각도 postion 위치 버그
//            // 각도 눈금 (30도 간격)
//            ForEach(0..<12) { i in
//                let angle = Double(i) * 30
//                if angle != 0 && angle != 90 && angle != 180 && angle != 270 {
//                    Text("\(Int(angle))°")
//                        .font(.system(size: 12, weight: .light))
//                        .foregroundColor(.secondary)
//                        .offset(y: -(size / 2) + 35)
//                        .rotationEffect(Angle(degrees: Double(i) * 30))
//                        .rotationEffect(Angle(degrees: -Double(i) * 30))
//                }
//            }
        }
    }
}

// 나침반 방향 표시 뷰
struct CompassDirectionView: View {
    let direction: String
    let size: CGFloat
    var isMainDirection: Bool = true
    
    var body: some View {
        VStack {
            Text(direction)
                .font(.system(size: isMainDirection ? 22 : 16, weight: isMainDirection ? .bold : .medium))
                .foregroundColor(direction == "N" ? .red : .primary)
            
            Rectangle()
                .fill(direction == "N" ? Color.red : Color.primary)
                .frame(width: isMainDirection ? 2 : 1, height: isMainDirection ? 20 : 10)
        }
        .offset(y: -(size / 2) + 50)
    }
}

// 나침반 십자선 뷰
struct CompassCrosshairView: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 1, height: 10)
            
            Rectangle()
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 10, height: 1)
        }
    }
}

// 삼각형 모양 (북쪽 방향 표시)
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// 위치 권한 요청 뷰
struct LocationPermissionView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("위치 접근 권한이 필요합니다")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("나침반을 사용하려면 '설정'에서 이 앱의 위치 접근 권한을 '앱을 사용하는 동안'으로 설정해주세요.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding()
            
            Button(action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("설정으로 이동")
                    .fontWeight(.semibold)
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}

#Preview {
    CompassView(viewModel: CompassViewModel())
}
