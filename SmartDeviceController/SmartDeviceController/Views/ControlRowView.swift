//
//  ControlRowView.swift
//  SmartDeviceController
//
//  Created by Aaron Flynn on 25/02/2025.
//

import SwiftUI

struct ControlRowView: View {
    let control: DeviceControl
    @Binding var controls: [DeviceControl]
    var sendMessage: (DeviceControl, String?) -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Topic: \(control.topic)")
                    .font(.headline)
                Text("Type: \(control.controlType.rawValue)")
                    .foregroundColor(.gray)
            }
            Spacer()
            renderControl()
        }
        .padding(.vertical, 5)
    }

    @ViewBuilder
    private func renderControl() -> some View {
        let controlIndex = controls.firstIndex(where: { $0.id == control.id })!

        switch control.controlType {
        case .button:
            Button("Send") {
                sendMessage(control, nil)
            }
            .buttonStyle(.borderedProminent)

        case .slider:
            Slider(
                value: Binding(
                    get: { Double(controls[controlIndex].message) ?? 0 },
                    set: { newValue in
                        controls[controlIndex].message = "\(Int(newValue))"
                        sendMessage(controls[controlIndex], "\(Int(newValue))")
                    }
                ),
                in: 0...100
            )
            .frame(width: 150)

        case .toggle:
            Toggle("", isOn: Binding(
                get: { controls[controlIndex].message.lowercased() == "on" },
                set: { newValue in
                    controls[controlIndex].message = newValue ? "ON" : "OFF"
                    sendMessage(controls[controlIndex], newValue ? "ON" : "OFF")
                }
            ))
            .toggleStyle(SwitchToggleStyle(tint: .blue))
        }
    }
}
