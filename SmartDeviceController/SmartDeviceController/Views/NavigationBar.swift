//
//  NavigationBarView.swift
//  SmartDeviceController
//
//  Created by Aaron Flynn on 14/01/2025.
//

import SwiftUI

struct NavigationBar: View {
    var body: some View {
        NavigationStack {
            VStack(){
                Text("Orders view")
                            .navigationTitle("Order title")
                            .navigationBarBackButtonHidden(true)
            }
            
            VStack {
                NavigationLink(destination: ContentView()) {
                    Text("Go to orders view")
                }
            }
            
            .navigationTitle("Our resturant")
            .toolbarBackground(Color.green, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                Button("Request order") {
                    print("Let's request a new order!")
                }
            }
        }
    }
}
