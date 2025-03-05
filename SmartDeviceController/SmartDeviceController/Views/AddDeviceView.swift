import SwiftUI

struct AddDeviceView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var deviceName: String = ""
    @State private var deviceLocation: String = ""
    @State private var customLocation: String = ""
    @State private var showingCustomLocation: Bool = false
    @State private var colorValue: Double = 0.5
    @State private var selectedSymbol: String = "lightbulb.fill"
    
    var onAdd: (Device) -> Void
    
    @State private var savedLocations: [String] = []
    let defaultLocations = ["Kitchen", "Living Room", "Bedroom", "Bathroom"]
    
    var selectedColor: Color {
        Color(hue: colorValue * 0.83, saturation: 1, brightness: 1)
    }
    
    let symbolCategories = [
        ("Lights & Power", ["lightbulb.fill", "light.max", "powerplug.fill", "bolt.fill"]),
        
        ("Appliances", ["fanblades.fill","desktopcomputer", "speaker.wave.2.fill"]),
        
        ("Home & Sensors", ["wifi", "house.fill", "thermometer"])
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Device Details")) {
                    TextField("Device Name", text: $deviceName)
                        .autocapitalization(.words)
                    
                    if showingCustomLocation {
                        HStack {
                            TextField("New Location", text: $customLocation)
                                .autocapitalization(.words)
                            
                            Button(action: {
                                addCustomLocation()
                            }) {
                                Text("Add")
                                    .foregroundColor(.blue)
                            }
                            .disabled(customLocation.isEmpty)
                        }
                    } else {
                        Picker("Location", selection: $deviceLocation) {
                            ForEach(allLocations, id: \.self) { location in
                                Text(location).tag(location)
                            }
                            
                            Divider()
                            Text("+ New Location").tag("addNew")
                        }
                        .pickerStyle(MenuPickerStyle())
                        .onChange(of: deviceLocation) { _, newValue in
                            if newValue == "addNew" {
                                
                                customLocation = ""
                                showingCustomLocation = true
                                deviceLocation = allLocations.first ?? ""
                            }
                        }
                    }
                }
                .onAppear {
                    loadLocations()
                    
                    if deviceLocation.isEmpty && !allLocations.isEmpty {
                        deviceLocation = allLocations[0]
                    }
                }
                
                Section(header: Text("Choose an Icon")) {
                    VStack(alignment: .center, spacing: 16) {
                        Image(systemName: selectedSymbol)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                            .foregroundColor(selectedColor)
                            .padding(12)
                            .background(
                                Circle()
                                    .fill(selectedColor.opacity(0.1))
                                    .overlay(
                                        Circle()
                                            .stroke(selectedColor, lineWidth: 2)
                                    )
                            )
                            .padding(.vertical, 10)
                                                
                        ForEach(symbolCategories, id: \.0) { category, symbols in
                            VStack(alignment: .leading) {
                                Text(category)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 4)
                                    .padding(.top, 8)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                                    ForEach(symbols, id: \.self) { symbol in
                                        Button(action: {
                                            selectedSymbol = symbol
                                        }) {
                                            Image(systemName: symbol)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 22, height: 22)
                                                .padding(8)
                                                .foregroundColor(selectedSymbol == symbol ? selectedColor : .primary)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(selectedSymbol == symbol ? selectedColor.opacity(0.15) : Color.gray.opacity(0.05))
                                                )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Choose a Color")) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                        
                            let sliderWidth = max(50, geometry.size.width)
                            let circleSize: CGFloat = 28
                            let trackHeight: CGFloat = 20
                            let offsetRange = sliderWidth - circleSize
                            
                        
                            RoundedRectangle(cornerRadius: trackHeight / 2)
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [
                                        .red, .orange, .yellow, .green, .blue, .purple, .pink
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .frame(height: trackHeight)
                            
                           
                            Circle()
                                .fill(selectedColor)
                                .frame(width: circleSize, height: circleSize)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                                .offset(x: colorValue * offsetRange)
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            if sliderWidth > 0 {
                                                let rawValue = value.location.x / sliderWidth
                                                colorValue = min(max(0, rawValue), 1)
                                            }
                                        }
                                )
                        }
                        .frame(height: 50)
                    }
                    .frame(height: 50)
                    .padding(.vertical, 8)
                }
            
                
                Section {
                    Button(action: {
                        let newDevice = Device(
                            id: Int.random(in: 1000...9999),
                            name: deviceName,
                            location: deviceLocation,
                            color: selectedColor,
                            image: selectedSymbol
                        )
                        onAdd(newDevice)
                        dismiss()
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .font(.headline)
                                .padding(.trailing, 4)
                            Text("Add Device")
                                .font(.headline)
                            Spacer()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(deviceName.isEmpty || deviceLocation.isEmpty)
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Add Device")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var allLocations: [String] {
        
        var combinedLocations = Set(defaultLocations)
        combinedLocations.formUnion(savedLocations)

        return Array(combinedLocations).sorted()
    }
    
    private func addCustomLocation() {
        guard !customLocation.isEmpty else { return }
        
        if !savedLocations.contains(customLocation) {
            savedLocations.append(customLocation)
            saveLocations()
            
        }
        
        deviceLocation = customLocation
        
        customLocation = ""
        showingCustomLocation = false
    }
    
    private func saveLocations() {
        UserDefaults.standard.set(savedLocations, forKey: "savedDeviceLocations")
    }
    
    private func loadLocations() {
        if let locations = UserDefaults.standard.stringArray(forKey: "savedDeviceLocations") {
            savedLocations = locations
        } else {
            savedLocations = []
        }
    }
}

struct AddDeviceView_Previews: PreviewProvider {
    static var previews: some View {
        AddDeviceView { _ in }
    }
}
