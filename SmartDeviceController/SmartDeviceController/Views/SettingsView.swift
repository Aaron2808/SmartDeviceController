import SwiftUI
import UserNotifications

struct SettingsView: View {
    @ObservedObject private var mqttBroker = MQTTBroker.shared
    @State private var connectionStatus = "Not Connected"
    @State private var isConnected = false
    @State private var connectionTimer: Timer?
    
    @State private var notificationsEnabled = false
    @State private var automationAlerts = true
    @State private var timerAlerts = true
    @State private var isSavingNotificationSettings = false
    
    @State private var advancedModeEnabled = false
    
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
                
                Section(header: Text("Notifications")) {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { oldValue, newValue in
                            if newValue {
                                requestNotificationPermission()
                            }
                        }
                    
                    if notificationsEnabled {
                        Toggle("Automation Alerts", isOn: $automationAlerts)
                            .onChange(of: automationAlerts) { _, _ in
                                saveNotificationSettings()
                            }
                        
                        Toggle("Timer Notifications", isOn: $timerAlerts)
                            .onChange(of: timerAlerts) { _, _ in
                                saveNotificationSettings()
                            }
                    }
                }
                
                Section(header: Text("Interface Settings")) {
                    Toggle("Advanced Mode", isOn: $advancedModeEnabled)
                        .onChange(of: advancedModeEnabled) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "advancedModeEnabled")
                            UserDefaults.standard.synchronize()
                        }
                        .tint(.blue)
                    
                    if advancedModeEnabled {
                        Text("Shows additional controls for motion, timers, and automations")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Enable to access advanced control features")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
            checkNotificationStatus()
            loadNotificationSettings()
            
            advancedModeEnabled = UserDefaults.standard.bool(forKey: "advancedModeEnabled")
        }
        .onDisappear {
            connectionTimer?.invalidate()
            connectionTimer = nil
            saveNotificationSettings()
        }
        .alert("Notification Settings", isPresented: $isSavingNotificationSettings) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please enable notifications in the system settings to receive updates from your devices.")
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
    
    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationsEnabled = (settings.authorizationStatus == .authorized)
            }
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    notificationsEnabled = true
                    NotificationHandler.shared.setupNotificationCategories()
                } else {
                    notificationsEnabled = false
                    isSavingNotificationSettings = true
                }
            }
        }
    }
    
    private func loadNotificationSettings() {
        automationAlerts = UserDefaults.standard.bool(forKey: "automationAlertsEnabled")
        timerAlerts = UserDefaults.standard.bool(forKey: "timerAlertsEnabled")
    }
    
    private func saveNotificationSettings() {
        UserDefaults.standard.set(automationAlerts, forKey: "automationAlertsEnabled")
        UserDefaults.standard.set(timerAlerts, forKey: "timerAlertsEnabled")
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
        }
    }
}
