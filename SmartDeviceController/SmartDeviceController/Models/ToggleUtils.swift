//
//  to.swift
//  SmartDeviceController
//
//  Created by Aaron Flynn on 22/03/2025.
//


import Foundation

class ToggleUtils {
    
    static func getToggleMessages(from configString: String) -> (onMessage: String, offMessage: String) {
        if configString.contains("|") {
            let parts = configString.split(separator: "|", maxSplits: 1).map { String($0) }
            
            let onMessage = parts[0].isEmpty ? "on" : parts[0]
            
            let offMessage = parts.count > 1 ?
                (parts[1].isEmpty ? "off" : parts[1]) :
                "off"
            
            return (onMessage, offMessage)
        }
        
        return (configString.isEmpty ? "on" : configString, "off")
    }
    
    static func getToggleOnMessage(from configString: String) -> String {
        if configString.contains("|") {
            let parts = configString.split(separator: "|", maxSplits: 1)
            return String(parts[0])
        }
        return configString.isEmpty ? "on" : configString
    }
    
    static func getToggleOffMessage(from configString: String) -> String {
        if configString.contains("|") {
            let parts = configString.split(separator: "|", maxSplits: 1)
            return parts.count > 1 ? String(parts[1]) : "off"
        }
        return "off"
    }
}
