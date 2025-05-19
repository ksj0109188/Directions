//
//  BluetoothView.swift
//  CoreDirections
//
//  Created on 5/18/25.
//

import SwiftUI
import CoreBluetooth

struct BluetoothView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @Environment(\.presentationMode) var presentationMode
    
    // 상태 변수
    @State private var showFirstTimeInfo: Bool = true
    
    var body: some View {
        NavigationView {
            VStack {
                if showFirstTimeInfo {
                    // 첫 사용 시 정보 및 권한 안내
                    bluetoothInfoView
                } else if bluetoothManager.isConnected {
                    // 연결된 상태 화면
                    connectedDeviceView
                } else {
                    // 기기 검색 리스트
                    deviceListView
                }
            }
            .padding()
            .navigationTitle("블루투스 연결")
            .navigationBarItems(
                leading: showFirstTimeInfo ? nil : Button(action: {
                    if bluetoothManager.isAdvertising {
                        bluetoothManager.stopAdvertising()
                    } else {
                        bluetoothManager.startAdvertising()
                    }
                }) {
                    Text(bluetoothManager.isAdvertising ? "광고 중지" : "광고 시작")
                },
                trailing: Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("닫기")
                }
            )
        }
    }
    
    // 블루투스 정보 및 첫 사용 가이드 화면
    private var bluetoothInfoView: some View {
        VStack(spacing: 25) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("블루투스 기기에 연결하기")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("이 기능을 사용하면 주변의 블루투스 기기를 검색하고, 연결하여 나침반 데이터를 전송할 수 있습니다.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Spacer().frame(height: 20)
            
            // 권한 요청 및 광고 시작 버튼
            Button(action: {
                // 사용자가 명시적으로 블루투스 권한 요청
                bluetoothManager.startAdvertising()
                showFirstTimeInfo = false
            }) {
                Text("블루투스 광고 시작")
                    .fontWeight(.semibold)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 50)
            
            Spacer()
            
            // 추가 설명
            VStack(alignment: .leading, spacing: 12) {
                Text("블루투스 연결은 다음과 같이 사용됩니다:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Mac 또는 다른 기기로 나침반 데이터 전송")
                }
                .font(.subheadline)
                
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("위치, 고도, 방향 정보를 실시간으로 공유")
                }
                .font(.subheadline)
                
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("권한을 허용하지 않으면 블루투스 기능을 사용할 수 없습니다.")
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
    
    // 연결된 기기 화면
    private var connectedDeviceView: some View {
        VStack(spacing: 20) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("\(bluetoothManager.connectedPeripheral?.name ?? "Unknown Device")에 연결됨")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("나침반 데이터가 실시간으로 전송되고 있습니다")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Divider()
            
            // 데이터 전송 정보
            HStack {
                Image(systemName: "arrow.up.arrow.down")
                    .foregroundColor(.blue)
                Text("데이터 형식: JSON")
            }
            .font(.subheadline)
            
            HStack {
                Image(systemName: "timer")
                    .foregroundColor(.blue)
                Text("전송 주기: 실시간")
            }
            .font(.subheadline)
            
            Spacer()
            
            Button(action: {
                bluetoothManager.stopAdvertising()
            }) {
                Text("연결 해제")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .cornerRadius(10)
            }
        }
    }
    
    // 기기 리스트 화면
    private var deviceListView: some View {
        VStack {
            // 이제 "검색된 기기"가 아닌 "광고 상태"를 표시
            if bluetoothManager.isAdvertising {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    
                    Text("블루투스 광고 중입니다...")
                        .foregroundColor(.secondary)
                    
                    Text("다른 기기들이 이 앱을 발견하고 연결할 수 있습니다.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                    
                    // 연결된 기기 수 표시
                    Text("연결된 기기: \(bluetoothManager.subscribedCentrals.count)개")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .padding(.top, 16)
                }
                .padding()
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("블루투스 광고가 중지되었습니다")
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        bluetoothManager.startAdvertising()
                    }) {
                        Text("광고 시작")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                .padding()
            }
        }
    }
}

#Preview {
    BluetoothView(bluetoothManager: BluetoothManager())
}
