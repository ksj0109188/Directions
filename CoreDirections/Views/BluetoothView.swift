//
//  BluetoothView.swift
//  CoreDirections
//
//  Created on 5/18/25.
//

import SwiftUI
import CoreBluetooth

struct BluetoothView: View {
    @ObservedObject var arduinoBluetoothManager: ArduinoBluetoothManager
    @Environment(\.presentationMode) var presentationMode
    
    // 상태 변수
    @State private var showFirstTimeInfo: Bool = true
    
    var body: some View {
        NavigationView {
            VStack {
                if showFirstTimeInfo {
                    // 첫 사용 시 정보 및 권한 안내
                    bluetoothInfoView
                } else if arduinoBluetoothManager.isConnected {
                    // 연결된 상태 화면
                    connectedDeviceView
                } else {
                    // 기기 검색 리스트
                    deviceListView
                }
            }
            .padding()
            .navigationTitle("아두이노 연결")
            .navigationBarItems(
                leading: showFirstTimeInfo ? nil : Button(action: {
                    if arduinoBluetoothManager.isScanning {
                        arduinoBluetoothManager.stopScanning()
                    } else {
                        arduinoBluetoothManager.startScanning()
                    }
                }) {
                    Text(arduinoBluetoothManager.isScanning ? "스캔 중지" : "스캔 시작")
                },
                trailing: Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("닫기")
                }
            )
        }
    }
    
    // MARK: - 첫 사용 정보 화면
    private var bluetoothInfoView: some View {
        VStack(spacing: 20) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("아두이노 블루투스 연결")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(icon: "1.circle.fill", text: "블루투스가 켜져있는 모든 기기를 검색합니다")
                InfoRow(icon: "2.circle.fill", text: "목록에서 연결할 기기를 선택하세요")
                InfoRow(icon: "3.circle.fill", text: "연결 후 나침반 데이터를 전송할 수 있습니다")
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            Button(action: {
                showFirstTimeInfo = false
                arduinoBluetoothManager.startScanning()
            }) {
                Text("BLE 기기 검색 시작")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
    
    // MARK: - 연결된 기기 화면
    private var connectedDeviceView: some View {
        VStack(spacing: 20) {
            // 연결 상태 표시
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text("연결됨")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Text(arduinoBluetoothManager.connectedPeripheral?.name ?? "Arduino")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(10)
            
            // 연결 강도 표시
            if arduinoBluetoothManager.connectionStrength != 0 {
                HStack {
                    Text("신호 강도:")
                    Text("\(arduinoBluetoothManager.connectionStrength) dBm")
                        .fontWeight(.semibold)
                    Spacer()
                }
            }
            
            // 명령 전송 통계
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("전송된 명령:")
                    Text("\(arduinoBluetoothManager.commandsSent)")
                        .fontWeight(.semibold)
                    Spacer()
                }
                
                if !arduinoBluetoothManager.lastSentCommand.isEmpty {
                    HStack {
                        Text("마지막 명령:")
                        Text(arduinoBluetoothManager.lastSentCommand)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            // 데이터 전송 상태 표시
            VStack(spacing: 12) {
                Text("데이터 전송 상태")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("나침반 데이터 전송 중")
                            .font(.subheadline)
                        Spacer()
                    }
                    
                    HStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                        Text("위치 정보 전송 중")
                            .font(.subheadline)
                        Spacer()
                    }
                    
                    HStack {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                        Text("센서 데이터 전송 중")
                            .font(.subheadline)
                        Spacer()
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
            
            Spacer()
            
            // 연결 해제 버튼
            Button(action: {
                arduinoBluetoothManager.disconnect()
            }) {
                Text("연결 해제")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
    
    // MARK: - 기기 검색 리스트 화면
    private var deviceListView: some View {
        VStack {
            // 상태 메시지
            Text(arduinoBluetoothManager.statusMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding()
            
            if arduinoBluetoothManager.isScanning {
                ProgressView("아두이노 검색 중...")
                    .padding()
            }
            
            if arduinoBluetoothManager.discoveredPeripherals.isEmpty && !arduinoBluetoothManager.isScanning {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("BLE 기기를 찾을 수 없습니다")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("주변에 블루투스가 켜져있는 기기가 있는지 확인하세요")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("다시 검색") {
                        arduinoBluetoothManager.startScanning()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            } else {
                List(arduinoBluetoothManager.discoveredPeripherals, id: \.identifier) { peripheral in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(peripheral.name ?? "Unknown Device")
                                .font(.headline)
                            
                            Text(peripheral.identifier.uuidString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("연결") {
                            arduinoBluetoothManager.connect(to: peripheral)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - 헬퍼 뷰들
struct InfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

#Preview {
    BluetoothView(arduinoBluetoothManager: ArduinoBluetoothManager())
}
