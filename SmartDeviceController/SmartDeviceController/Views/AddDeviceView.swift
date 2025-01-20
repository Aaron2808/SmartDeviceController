//
//  AddDeviceView.swift
//  SmartDeviceController
//
//  Created by Aaron Flynn on 14/01/2025.
//

import SwiftUI

struct AddDeviceView: View {
    
    var mqttManager: MQTTBroker?
    var connectionCallback: ((String) -> Void)?
    
    @State var temp: String = ""
    
    @State var hostMQTT: String = ""
    @State var portMQTT: String = ""
    
    @State var connectionStatus = "Not Connected"
    @State var status: Bool = true
    
    func isConnected(){
        
        if(status){
            connectionStatus = "Connected"
        }
        else{
            connectionStatus = "Not Connected"
        }
        
    }
    
    var body: some View {
        Spacer()
        
        VStack{
            Text("Status: " + connectionStatus)
                .bold()
        }
        
        HStack{
            HStack{
                VStack{
                    Text("Host")
                        .padding(10)
                        .bold()
                    
                    Text("Port")
                        .padding(10)
                        .bold()
                }
                
            }
            
            HStack{
                VStack{
                    TextField("", text: $hostMQTT)
                        .border(.black)
                        .frame(width:150, height:30)
                        .padding(5)
                    
                    TextField("", text: $portMQTT)
                        .border(.black)
                        .frame(width:150, height:30)
                        .padding(5)
                    
                }
            }
        }.frame(width: 400, height:200)
            .background(Color.white)
            .cornerRadius(10)
        
        
        VStack{
            Button("Connect") {
                print("Attempting to Connect")
                
                // Attempt to connect
                mqttManager?.connect()
                
                isConnected()
            }.foregroundColor(.white)
            
        }.frame(width:130, height:40)
            .background(.gray)
            .cornerRadius(20)
        
        Spacer()
    }
}

#Preview {
    AddDeviceView()
}
