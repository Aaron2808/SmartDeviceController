import SwiftUI

struct DeviceGridView: View {
    @State private var settingView: Bool = false
    @State private var showAddDeviceForm = false
    @State private var showMQTTDevices = false
    @State private var isConnecting = false
    @State private var showSideMenu = false
    @State private var showEnergyCostView = false
    @State private var showAllAutomations = false
    
    @ObservedObject private var mqttBroker = MQTTBroker.shared
    @ObservedObject private var automationManager = AutomationManager.shared
    
    @State private var devices: [Device] = []
    
    let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    var body: some View {
        ZStack {
            NavigationStack {
                VStack(spacing: 0) {
                    HStack {
                        Button(action: {
                            withAnimation(.easeInOut) {
                                showSideMenu = true
                            }
                        }) {
                            Image(systemName: "list.bullet")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 25, height: 25)
                                .foregroundColor(.black).opacity(0.5)
                                .padding(30)
                        }
                        
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
                        
                    }
                    .frame(maxWidth: .infinity, maxHeight: 40)
                    
                    
                    VStack {
                        if(!devices.isEmpty){
                            ScrollView {
                                LazyVGrid(columns: columns, spacing: 20) {
                                    ForEach(devices) { device in
                                        NavigationLink(destination: DeviceControlView(device: device)) {
                                            VStack {
                                                DeviceCard(device: device)
                                                // Show MQTT topic if available
                                                if let topic = device.mqttTopic, !topic.isEmpty {
                                                    Text(topic)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                        .lineLimit(1)
                                                        .truncationMode(.middle)
                                                        .frame(maxWidth: 140)
                                                }
                                            }
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
                                    DeviceManager.shared.saveDevices(devices)
                                }
                            }
                        }.frame(maxWidth: .infinity, maxHeight: 70)
                    }
                }
                .navigationDestination(isPresented: $showEnergyCostView) {
                    EnergyCostView()
                }
                .navigationDestination(isPresented: $showAllAutomations) {
                    AllAutomationsView()
                }
            }
            .onAppear {
                mqttBroker.autoConnect()
                
                if automationManager.isProcessingEnabled {
                    automationManager.startMonitoring()
                }
                
                loadDevices()
            }
            
            SideMenuView(isShowing: $showSideMenu,
                         showEnergyCostView: $showEnergyCostView)
                .opacity(showSideMenu ? 1 : 0)
        }
    }
    
    private func deleteDevice(_ device: Device) {
        devices.removeAll { $0.id == device.id }
        DeviceManager.shared.saveDevices(devices)
    }
    
    private func loadDevices() {
        devices = DeviceManager.shared.loadDevices()
        
        // If no devices exist yet, create some defaults
        if devices.isEmpty {
            devices = [
                Device(id: 3, name: "Smart Plug", location: "Kitchen", color: .red, image: "poweroutlet.type.g", mqttTopic: nil),
                Device(id: 1, name: "Smart Light", location: "Kitchen", color: .blue, image: "lightbulb", mqttTopic: nil),
                Device(id: 2, name: "Thermostat", location: "Living Room", color: .yellow, image: "thermometer", mqttTopic: nil),
                Device(id: 4, name: "Humidity Sensor", location: "Hall", color: .orange, image: "humidifier", mqttTopic: nil)
            ]
            DeviceManager.shared.saveDevices(devices)
        }
    }
}

struct SideMenuView: View {
    @Binding var isShowing: Bool
    @Binding var showEnergyCostView: Bool
    @State private var showAllAutomations = false
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            if isShowing {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut) {
                            isShowing = false
                        }
                    }
            }
            
            // Side menu
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack {
                        Text("Menu")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation(.easeInOut) {
                                isShowing = false
                            }
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.primary)
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 20)
                    
                    Divider()
                    
                    // Menu items
                    VStack(spacing: 0) {
                        // Devices
                        Button(action: {
                            withAnimation(.easeInOut) {
                                isShowing = false
                            }
                        }) {
                            MenuRow(title: "Devices", icon: "house")
                        }
                        
                        // Energy Cost View
                        Button(action: {
                            withAnimation(.easeInOut) {
                                isShowing = false
                                showEnergyCostView = true
                            }
                        }) {
                            MenuRow(title: "Energy Costs", icon: "bolt.circle.fill")
                        }
                        
                        // ALL Automations
                        Button(action: {
                            withAnimation(.easeInOut) {
                                isShowing = false
                                showAllAutomations = true
                            }
                        }) {
                            MenuRow(title: "Automations", icon: "wand.and.stars")
                        }
                    }
                    Spacer()
                
                }
                .frame(width: 280)
                .background(Color(.systemBackground))
                .offset(x: isShowing ? 0 : -280)
                .animation(.easeInOut(duration: 0.3), value: isShowing)
                
                Spacer()
            }
        }
        .zIndex(100)
        .sheet(isPresented: $showAllAutomations) {
            AllAutomationsView()
        }
    }
}



#Preview{
    DeviceGridView()
}
