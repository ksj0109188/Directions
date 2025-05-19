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
    
    var body: some View {
        NavigationView {
            VStack {
                if bluetoothManager.isConnected {
                    // 연결된 상태 화면
                    connectedDeviceView
                } else {
                    // 기기 검색 리스트
                    deviceListView
                }
            }
            .padding()
            .navigationTitle("블루투스 연결")
            .navigationBarItems(trailing: Button(action: {
                if bluetoothManager.isScanning {
                    bluetoothManager.stopScanning()
                } else {
                    bluetoothManager.startScanning()
                }
            }) {
                Text(bluetoothManager.isScanning ? "스캔 중지" : "스캔 시작")
            })
        }
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
                bluetoothManager.disconnect()
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
            if bluetoothManager.discoveredPeripherals.isEmpty {
                if bluetoothManager.isScanning {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("주변 기기를 검색 중입니다...")
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "antenna.radiowaves.left.and.right.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        
                        Text("검색된 기기가 없습니다")
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            bluetoothManager.startScanning()
                        }) {
                            Text("스캔 시작")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    }
                }
            } else {
                List {
                    Section(header: Text("검색된 기기")) {
                        ForEach(bluetoothManager.discoveredPeripherals, id: \.identifier) { peripheral in
                            Button(action: {
                                bluetoothManager.connect(to: peripheral)
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(peripheral.name ?? "Unknown Device")
                                            .fontWeight(.semibold)
                                        Text(peripheral.identifier.uuidString)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.blue)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    BluetoothView(bluetoothManager: BluetoothManager())
}
