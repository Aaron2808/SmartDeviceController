//
//  ControlModule.swift
//  SmartDeviceController
//
//  Created by Aaron Flynn on 04/03/2025.
//

import SwiftUI


struct ControlModule {
    let name: String
    let description: String
    let type: ControlType
    let icon: Image
    let color: Color
    
    static let allModules: [ControlModule] = [
        ControlModule(
            name: "Button",
            description: "",
            type: .button,
            icon: Image(systemName: "button.programmable"),
            color: .blue
        ),
        ControlModule(
            name: "Toggle Switch",
            description: "",
            type: .toggle,
            icon: Image(systemName: "switch.2"),
            color: .green
        ),
        ControlModule(
            name: "Slider",
            description: "",
            type: .slider,
            icon: Image(systemName: "slider.horizontal.3"),
            color: .orange
        ),
        ControlModule(
            name: "Data Monitor",
            description: "",
            type: .dataDisplay,
            icon: Image(systemName: "chart.bar"),
            color: .purple
        )
    ]
}
