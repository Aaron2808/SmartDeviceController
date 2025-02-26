import SwiftUI

struct AddDeviceView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var deviceName: String = ""
    @State private var deviceLocation: String = ""
    @State private var colorValue: Double = 0.5
    @State private var selectedSymbol: String = "bolt.fill" // Default SF Symbol
    
    var onAdd: (Device) -> Void
    
    let locations = ["Kitchen","Sitting Room", "Hallway", "Bedroom"]
    
    var selectedColor: Color {
        Color(hue: colorValue * 0.83, saturation: 1, brightness: 1)
    }
    
    let symbols = [
        "lightbulb.fill", "powerplug.fill", "fanblades.fill",
        "tv.fill", "display", "desktopcomputer",
        "speaker.wave.2.fill", "wifi", "house.fill",
        "thermometer.sun.fill", "flame.fill", "bolt.fill"
    ]
    
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Device Details")) {
                    TextField("Device Name", text: $deviceName)
                }
                
                Section(header: Text("Select Location")){
                    Picker("Location", selection: $deviceLocation) {
                                       ForEach(locations, id: \.self) { location in
                                           Text(location)
                                       }
                                   }
                                   .pickerStyle(MenuPickerStyle())
                }
                
                Section(header: Text("Choose an Icon")) {
                    VStack {
                      
                        Image(systemName: selectedSymbol)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                            .foregroundColor(.black)
                            .padding(10)
                            .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.black, lineWidth: 2)
                                )
                        
                    
                        ScrollView {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                                ForEach(symbols, id: \.self) { symbol in
                                    Button(action: {
                                        selectedSymbol = symbol
                                    }) {
                                        Image(systemName: symbol)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 25, height: 25)
                                            .padding()
                                            .background(selectedSymbol == symbol ? Color.gray.opacity(0.2) : Color.clear)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.vertical, 5)
                        }
                        .frame(maxHeight: 100)
                    }
                }
                
                Section(header: Text("Choose a Color")) {
                    VStack {
                        ZStack(alignment: .leading) {
                            let sliderWidth: CGFloat = 350
                            let circleSize: CGFloat = 35
                            
                            Rectangle()
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(hue: 0.0, saturation: 1, brightness: 1),
                                        Color(hue: 0.15, saturation: 1, brightness: 1),
                                        Color(hue: 0.25, saturation: 1, brightness: 1),
                                        Color(hue: 0.4, saturation: 1, brightness: 1),
                                        Color(hue: 0.6, saturation: 1, brightness: 1),
                                        Color(hue: 0.83, saturation: 1, brightness: 1)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .frame(width: sliderWidth, height: 30)
                                .cornerRadius(15)
                            
                            Circle()
                                .fill(selectedColor)
                                .frame(width: circleSize, height: circleSize)
                                .offset(x: CGFloat(colorValue * (sliderWidth - circleSize)))
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let newValue = min(max(0, value.location.x / sliderWidth), 1)
                                            colorValue = newValue
                                        }
                                )
                        }
                        .frame(width: 350, height: 35)
                        .clipped()
                    }
                    .padding(.vertical, 10)
                }
                
                Button("Add Device") {
                    let newDevice = Device(
                        id: Int.random(in: 1000...9999),
                        name: deviceName,
                        location: deviceLocation,
                        color: selectedColor,
                        image: selectedSymbol
                    )
                    onAdd(newDevice)
                    dismiss()
                }
                .disabled(deviceName.isEmpty || deviceLocation.isEmpty)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .cornerRadius(8)
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
}

