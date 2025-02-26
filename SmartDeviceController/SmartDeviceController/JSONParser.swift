//
//  JSONParser.swift
//  SmartDeviceController
//
//  Created by Aaron Flynn on 25/02/2025.
//

import Foundation

struct JSONParser {
    static func parseAnyJSON(_ jsonString: String) -> String {
        guard let jsonData = jsonString.data(using: .utf8) else { return "Invalid JSON" }
        
        do {
            _ = JSONDecoder()
            
            // Otherwise, parse as a generic dictionary
            if let jsonDict = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                return formatDynamicJSON(jsonDict)
            }
            
            return "Unknown JSON format"
        } catch {
            return "Error decoding JSON: \(error.localizedDescription)"
        }
    }

    static func formatDynamicJSON(_ jsonDict: [String: Any]) -> String {
        return jsonDict.map { key, value in
            if let nestedDict = value as? [String: Any] {
                return "**\(key):**\n\(formatDynamicJSON(nestedDict).replacingOccurrences(of: "\n", with: "\n  "))"
            } else if let array = value as? [Any] {
                return "**\(key):** [\(array.map { "\($0)" }.joined(separator: ", "))]"
            } else {
                return "**\(key):** \(value)"
            }
        }
        .joined(separator: "\n")
    }
}
