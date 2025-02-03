import SwiftUI

struct AddControlView: View {
    @Binding var controls: [DeviceControl]
    let deviceId: Int
    let saveControls: () -> Void
    @ObservedObject private var mqttBroker = MQTTBroker.shared

    @State private var selectedTopic: String = ""
    @State private var selectedControlType: ControlType = .button
    @State private var message: String = ""

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select Control Type")) {
                    Picker("Control Type", selection: $selectedControlType) {
                        ForEach(ControlType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Section(header: Text("Select Topic")) {
                    Picker("Topic", selection: $selectedTopic) {
                        ForEach(mqttBroker.topics.sorted(), id: \.self) { topic in
                            Text(topic).tag(topic)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                Section(header: Text("Default Message")) {
                    TextField("Enter default message", text: $message)
                        .disabled(selectedControlType == .slider) // Slider sets value dynamically
                }
            }
            .navigationBarTitle("Add Control", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    addControl()
                }
                .disabled(selectedTopic.isEmpty)
            )
        }
    }

    private func addControl() {
        let newControl = DeviceControl(id: UUID().hashValue, topic: selectedTopic, message: message, controlType: selectedControlType)
        controls.append(newControl)
        saveControls()
        presentationMode.wrappedValue.dismiss()
    }
}

enum ControlType: String, Codable, CaseIterable {
    case button = "Button"
    case slider = "Slider"
    case toggle = "Toggle"
}


