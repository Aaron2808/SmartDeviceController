import SwiftUI

struct HomeView: View {
    var body: some View {
        VStack {
           
        }
    }
}


struct DeviceControl: Identifiable, Codable {
    let id: Int
    let topic: String
    var message: String
    let controlType: ControlType
}

#Preview {
    HomeView()
}
