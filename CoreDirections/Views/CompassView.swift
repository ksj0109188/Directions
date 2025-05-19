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
    @State private var showPermissionAlert: Bool = false
    
    // 메인 나침반 크기 계산을 위한 환경변수
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var compassSize: CGFloat {
        horizontalSizeClass == .compact ? 280 : 350
    }
    
    var body: some View {
        VStack {
            if !viewModel.isAuthorized {
                // 위치 권한 요청 화면
                PermissionRequestView(viewModel: viewModel)
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
                    
                    // 블루투스 광고 시작 버튼
                    Button {
                        // 블루투스 권한이 처음 요청될 때 알림 표시
                        showPermissionAlert = true
                    } label: {
                        Label("데이터 전송", systemImage: "antenna.radiowaves.left.and.right")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }
                    .alert(isPresented: $showPermissionAlert) {
                        Alert(
                            title: Text("블루투스 권한 필요"),
                            message: Text("다른 기기로 나침반 데이터를 전송하기 위해 블루투스 권한이 필요합니다. 계속 진행하시겠습니까?"),
                            primaryButton: .default(Text("계속")) {
                                // 사용자가 명시적으로 동의한 후에만 블루투스 광고 시작
                                isFindBluetooth = true
                                viewModel.startBluetoothAdvertising()
                            },
                            secondaryButton: .cancel(Text("취소"))
                        )
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
                    .onAppear {
                        // 뷰가 나타날 때 모션 서비스 시작 (권한 있는 경우에만)
                        if viewModel.isAuthorized && !viewModel.isMotionServicesInitialized {
                            viewModel.startMotionServices()
                        }
                    }
                    
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
            BluetoothView(bluetoothManager: viewModel.bluetoothManager)
        }
    }
}

// 권한 요청 화면
struct PermissionRequestView: View {
    @ObservedObject var viewModel: CompassViewModel
    
    var body: some View {
        VStack(spacing: 25) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("나침반을 사용하려면 위치 권한이 필요합니다")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("이 앱은 방향과 위치 정보를 표시하기 위해 위치 서비스에 접근해야 합니다. 권한을 허용하지 않으면 나침반 기능을 사용할 수 없습니다.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Spacer().frame(height: 20)
            
            // 권한 요청 버튼
            Button(action: {
                // 사용자가 명시적으로 위치 권한 요청
                viewModel.startLocationServices()
            }) {
                Text("위치 권한 허용")
                    .fontWeight(.semibold)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 50)
            
            // 설정으로 이동 버튼
            Button(action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("설정에서 변경하기")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.blue)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.blue, lineWidth: 1)
                    )
            }
            .padding(.horizontal, 50)
            
            Spacer()
            
            // 권한 설명 메시지
            VStack(alignment: .leading, spacing: 12) {
                Text("위치 정보는 다음과 같이 사용됩니다:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("정확한 방위각 계산")
                }
                .font(.subheadline)
                
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("현재 위치의 좌표 및 주소 표시")
                }
                .font(.subheadline)
                
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("고도 정보 표시")
                }
                .font(.subheadline)
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
        }
        .padding()
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

#Preview {
    CompassView(viewModel: CompassViewModel())
}
