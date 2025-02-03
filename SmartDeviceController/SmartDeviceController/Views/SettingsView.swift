import UIKit
import SwiftUI
import SwiftUICore

struct TopicDetails: Identifiable {
    let id = UUID()  // Unique identifier for each instance
    let details: String
}

struct SettingsView: View {
    
    var connectionCallback: ((String) -> Void)?
    
    @State var temp: String = ""
    @State var selectedTopicDetails: TopicDetails? = nil
    @State var connectionStatus = "Not Connected"
    @State var status: Bool = false
    @ObservedObject private var mqttBroker = MQTTBroker.shared
    
    func updateConnectionStatus() {
        connectionStatus = status ? "Connected" : "Not Connected"
    }
    
    var body: some View {
        VStack {
            Text("Settings").bold()
            
            List {
                HStack {
                    Text("Connection Status:").bold()
                    Spacer()
                    Text(connectionStatus).foregroundColor(.gray)
                }
                
                HStack {
                    Text("Client ID ").bold()
                    Spacer()
                    Text(mqttBroker.clientID).foregroundColor(.gray)
                }
                
                HStack {
                    Text("Host Address").bold()
                    Spacer()
                    Text(mqttBroker.hostAddress).foregroundColor(.gray)
                }
                
                HStack {
                    Text("Port:").bold()
                    Spacer()
                    Text("\(mqttBroker.port)").foregroundColor(.gray)
                }
                
                HStack {
                    Button("Connect", action: {
                        mqttBroker.connect()
                        updateConnectionStatus()
                    })
                    .frame(width: 150, height: 40)
                    .foregroundColor(.white)
                    .background(.blue)
                    .disabled(status)
                    
                    Spacer()
                    
                    Button("Disconnect", action: {
                        mqttBroker.disconnect()
                        updateConnectionStatus()
                    })
                    .frame(width: 150, height: 40)
                    .foregroundColor(.white)
                    .background(.blue)
                    .disabled(!status)
                }
            }
            
            VStack {
                Text("Available Topics")
                    .font(.title)
                    .bold()
                
                List(Array(mqttBroker.topics.sorted()), id: \.self) { topic in
                    HStack {
                        Text(topic)
                            .font(.body)
                            .padding(.leading, 10)
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                    .shadow(radius: 5)
                    .onTapGesture {
                        loadTopicDetails(for: topic)
                    }
                }
                .listStyle(PlainListStyle())
                
                Button("Search") {
                    mqttBroker.searchTopics()
                }
            }
            .sheet(item: $selectedTopicDetails) { details in
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
            Spacer()
        }
    }
    
    private func loadTopicDetails(for topic: String) {
        // Ensure decoding runs in the background to prevent blocking the UI
        DispatchQueue.global(qos: .background).async {
           // let message = $mqttBroker.recievedMessage(for: topic) ?? "No message available for this topic."
            //let formattedMessage = formatMessage(message)
            
            DispatchQueue.main.async {
                //selectedTopicDetails = TopicDetails(details: formattedMessage)
            }
        }
    }
}

#Preview {
    SettingsView()
}

func formatMessage(_ message: String) -> String {
    guard let data = message.data(using: .utf8) else { return "Invalid message" }
    do {
        // Decode JSON into a dictionary for pretty printing
        if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            return json.map { "\($0.key): \($0.value)" }
                .joined(separator: "\n")
        }
        return "Failed to parse JSON"
    } catch {
        return "Error decoding message: \(error.localizedDescription)"
    }
}
