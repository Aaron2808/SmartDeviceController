import SwiftUI

struct TopicDetails: Identifiable {
    let id = UUID()
    let topic: String
    let details: String
}

struct SettingsView: View {
    @ObservedObject private var mqttBroker = MQTTBroker.shared
    @State private var selectedTopicDetails: TopicDetails? = nil
    @State private var connectionStatus = "Not Connected"
    @State private var isConnected = false
    
    func updateConnectionStatus() {
        connectionStatus = isConnected ? "Connected" : "Not Connected"
    }
    
    var body: some View {
        VStack {
            List {
                connectionInfoSection
                connectionButtons
            }
            
            VStack {
                Text("Available Devices")
                    .font(.title2)
                    .bold()
                
                List {
                    ForEach(mqttBroker.groupedTopics.keys.sorted(), id: \.self) { deviceID in
                        DisclosureGroup(deviceID) {
                            ForEach(mqttBroker.groupedTopics[deviceID]!.keys.sorted(), id: \.self) { attribute in
                                Button(action: {
                                    loadTopicDetails(for: deviceID, attribute: attribute)
                                }) {
                                    HStack {
                                        Text(attribute)
                                        Spacer()
                                        Text(mqttBroker.groupedTopics[deviceID]?[attribute] ?? "N/A")
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Button("Search for Topics") {
                    mqttBroker.searchTopics()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .sheet(item: $selectedTopicDetails) { details in
            topicDetailsView(details: details)
        }
    }
    
    private var connectionInfoSection: some View {
        Section {
            HStack {
                Text("Connection Status:").bold()
                Spacer()
                Text(connectionStatus).foregroundColor(isConnected ? .green : .red)
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
    }
    
    private var connectionButtons: some View {
        HStack {
            Button("Connect") {
                mqttBroker.connect()
                isConnected = true
                updateConnectionStatus()
            }
            .frame(width: 150, height: 40)
            .background(isConnected ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .disabled(isConnected)
            
            Spacer()
            
            Button("Disconnect") {
                mqttBroker.disconnect()
                isConnected = false
                updateConnectionStatus()
            }
            .frame(width: 150, height: 40)
            .background(!isConnected ? Color.gray : Color.red)
            .foregroundColor(.white)
            .disabled(!isConnected)
        }
    }
    
    private func loadTopicDetails(for deviceID: String, attribute: String) {
        if let rawMessage = mqttBroker.groupedTopics[deviceID]?[attribute] {
            let formattedDetails = JSONParser.parseAnyJSON(rawMessage)
            selectedTopicDetails = TopicDetails(topic: "\(deviceID)/\(attribute)", details: formattedDetails)
        } else {
            selectedTopicDetails = TopicDetails(topic: "\(deviceID)/\(attribute)", details: "No data available")
        }
    }
    
    private func topicDetailsView(details: TopicDetails) -> some View {
        VStack {
            Text("Topic Details")
                .font(.title)
                .bold()
            
            ScrollView {
                Text(details.details)
                    .padding()
                    .font(.body)
                    .multilineTextAlignment(.leading)
            }
            
            Button("Close") {
                selectedTopicDetails = nil
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
}

#Preview {
    SettingsView()
}
