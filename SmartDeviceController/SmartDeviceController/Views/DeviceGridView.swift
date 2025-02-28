//
//  DeviceGridView.swift
//  SmartDeviceController
//
//  Created by Aaron Flynn on 02/02/2025.
//

import SwiftUI

struct DeviceCard: View {
    let device: Device
    
    var body: some View {
        VStack(spacing:0) {
            Rectangle()
                .fill()
                .foregroundStyle(device.color)
                .frame(height: 10)
                .frame(maxWidth: .infinity)
            
            Text(device.name)
                .font(.system(size: 16).bold())
                .foregroundColor(.primary)
                .padding(.top, 10)
               
            Spacer()
            
            Image(systemName: device.image)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.black.opacity(0.6))
                .frame(width: 35, height: 35)
            
            Spacer()
            
            Text(device.location)
                .font(.subheadline)
                .foregroundColor(.black.opacity(0.7))
                .padding(.bottom, 10)
        }
        .frame(width: 150, height: 150, alignment: .top)
        .background(.white)
        .cornerRadius(10)
        .shadow(radius: 2)
    }

}

struct DeviceGridView: View {
    @State private var settingView: Bool = false
    @State private var showAddDeviceForm = false
    @State private var showMQTTDevices = false
    
    @State private var devices: [Device] = [
        Device(id: 1, name: "Smart Light", location: "Kitchen", color: .blue, image: "lightbulb"),
        Device(id: 2, name: "Thermostat", location: "Living Room", color: .yellow, image: "lightbulb"),
        Device(id: 3, name: "Smart Plug", location: "Kitchen", color: .red, image: "lightbulb"),
        Device(id: 4, name: "Security Camera", location: "Camera" ,color: .orange, image: "lightbulb")
    ]
    
    let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    var body: some View {
        NavigationStack {
            
            
            HStack{
                
                Button(action: {
                   
                }) {
                    Image(systemName: "list.bullet")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 25, height: 25)
                        .foregroundColor(.black).opacity(0.5)
                        .padding(30)
                }
                //.navigationDestination(isPresented: $settingView) {
                    //SettingsView()
                    //    .navigationTitle("Settings")
                //}
                
                Spacer()
                
                Text("Devices")
                    .font(.system(size: 25))
                    .bold()
                    .padding(30)
            
                
                Spacer()
                
                Button(action: {
                    settingView = true
                }) {
                    Image(systemName: "gearshape")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 25, height: 25)
                        .foregroundColor(.black).opacity(0.5)
                        .padding(30)
                }
                .navigationDestination(isPresented: $settingView) {
                    SettingsView()
                        .navigationTitle("Settings")
                }
                
            }.frame(maxWidth: .infinity, maxHeight: 40)
            
            
            VStack {
                
                if(!devices.isEmpty){
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(devices) { device in
                                NavigationLink(destination: DeviceControlView(device: device)) {
                                    DeviceCard(device: device)
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        deleteDevice(device)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(.gray.opacity(0.1))
                }
                else{
                   
                    VStack{
                        Spacer()
                        Text("No Devices Available")
                            .foregroundColor(.black)
                        Spacer()
                    }
                    .frame(maxWidth:.infinity, maxHeight: .infinity)
                    .background(.gray.opacity(0.1))
                }
                        
            
                VStack{
                    Button(action: {
                        showAddDeviceForm = true
                    }) {
                        Text("Add Device")
                            .foregroundColor(.white)
                            .frame(width: 200, height:50)
                            .background(Color.blue)
                            .cornerRadius(15)
                    }
                    .padding()
                    .sheet(isPresented: $showAddDeviceForm) {
                        AddDeviceView { newDevice in
                            devices.append(newDevice)
                        }
                    }
                }.frame(maxWidth: .infinity, maxHeight: 70)
            }
        }
    }
    
        private func deleteDevice(_ device: Device) {
            devices.removeAll { $0.id == device.id }
        }
}

#Preview{
    DeviceGridView()
}
