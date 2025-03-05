import SwiftUI

struct SettingsView: View {
    @ObservedObject private var mqttBroker = MQTTBroker.shared
    @State private var connectionStatus = "Not Connected"
    @State private var isConnected = false
    @State private var connectionTimer: Timer?
    
    func updateConnectionStatus() {
        connectionStatus = isConnected ? "Connected" : "Not Connected"
    }
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("Connection Info")) {
                    HStack {
                        Text("Connection Status:").bold()
                        Spacer()
                        Text(connectionStatus)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(isConnected ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                            .foregroundColor(isConnected ? .green : .red)
                            .cornerRadius(4)
                    }
                    HStack {
                        Text("Client ID:").bold()
                        Spacer()
                        Text(mqttBroker.clientID).foregroundColor(.gray)
                    }
                    HStack {
                        Text("Host Address:").bold()
                        Spacer()
                        Text(mqttBroker.hostAddress).foregroundColor(.gray)
                    }
                    HStack {
                        Text("Port:").bold()
                        Spacer()
                        Text("\(mqttBroker.port)").foregroundColor(.gray)
                    }
                }
                
                Section {
                    HStack {
                        Button("Connect") {
                            mqttBroker.connect()
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isConnected = mqttBroker.isConnected
                                updateConnectionStatus()
                                
                                if isConnected {
                                    mqttBroker.searchTopics()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isConnected ? Color.gray.opacity(0.5) : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(isConnected)
                        
                        Spacer()
                            .frame(width: 16)
                        
                        Button("Disconnect") {
                            mqttBroker.disconnect()
                            isConnected = false
                            updateConnectionStatus()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(!isConnected ? Color.gray.opacity(0.5) : Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(!isConnected)
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .onAppear {
            isConnected = mqttBroker.isConnected
            updateConnectionStatus()
            setupConnectionStatusUpdater()
        }
        .onDisappear {
            connectionTimer?.invalidate()
            connectionTimer = nil
        }
    }
    
    private func setupConnectionStatusUpdater() {
        connectionTimer?.invalidate()
        
        connectionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            let connected = self.mqttBroker.isConnected
            if self.isConnected != connected {
                self.isConnected = connected
                self.updateConnectionStatus()
            }
        }
        
        if let timer = connectionTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
}

#Preview {
    SettingsView()
}
