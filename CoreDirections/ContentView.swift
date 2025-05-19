//
//  ContentView.swift
//  CoreDirections
//
//  Created by 김성준 on 5/15/25.
//

import SwiftUI

struct ContentView: View {
    // 앱 수준에서 주입된 ViewModel 인스턴스 사용
    @EnvironmentObject private var viewModel: CompassViewModel
    
    var body: some View {
        NavigationView {
            CompassView(viewModel: viewModel)
                .navigationTitle("나침반")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(CompassViewModel())
}
