//
//  ContentView.swift
//  SmartDeviceController
//
//  Created by Aaron Flynn on 13/01/2025.
//

import SwiftUI

struct TestView: View {
    
    @State var device: String = ""
    @State var settingView: Bool = false
    var themeColor: Color = .gray
    var buttonColor: Color = .blue
    @State var mqttBroker = MQTTBroker()
    
    var body: some View {
        NavigationStack{
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
                    mqttBroker.publish(topic: "shellyplug1/command/switch:0", message: "on")
                }) {
                    Text("On")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                
                Button(action: {
                    mqttBroker.publish(topic: "shellyplug1/command/switch:0", message: "off")
                }) {
                    Text("Off")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                
                Button(action: {
                    mqttBroker.subscribe(topic: "test/topic")
                }) {
                    Text("Subscribe")
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
                
                
                
                Button(action: {
                    settingView = true
                }) {
                    Text("Settings")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .cornerRadius(8)
                }
                .navigationDestination(isPresented: $settingView) {
                    SettingsView()
                }
            }
            
            .padding()
        }
    }
}

#Preview {
    TestView()
}
