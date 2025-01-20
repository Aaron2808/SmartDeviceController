//
//  ContentView.swift
//  SmartDeviceController
//
//  Created by Aaron Flynn on 13/01/2025.
//

import SwiftUI

struct ContentView: View {
    
    @State var device: String = ""
    var themeColor: Color = .gray
    var buttonColor: Color = .blue
    @State var mqttBroker = MQTTBroker()
    
    var body: some View {
        VStack(spacing: 20) {
                    HStack {
                        Text("Device:")
                        TextField(
                            "Enter Device",
                            text: $device
                        )
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding()
                    
                    Button(action: {
                        mqttBroker.connect()
                    }) {
                        Text("Connect to HiveMQ")
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    
                    Button(action: {
                        mqttBroker.disconnect()
                    }) {
                        Text("Disconnect")
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
    }

#Preview {
    ContentView()
}
