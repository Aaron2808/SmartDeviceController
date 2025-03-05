//
//  JSONParser.swift
//  SmartDeviceController
//
//  Created by Aaron Flynn on 04/03/2025.
//
import SwiftUI

struct JSONParser {
    static func parseAnyJSON(_ rawJSON: String) -> String {
        if let jsonData = rawJSON.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: jsonData),
           let prettyJsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
           let prettyString = String(data: prettyJsonData, encoding: .utf8) {
            return prettyString
        }
        return rawJSON
    }
}
