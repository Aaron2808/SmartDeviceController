//
//  SideMenuView.swift
//  SmartDeviceController
//
//  Created by Aaron Flynn on 13/03/2025.
//

import SwiftUI

struct SideMenuView: View {
    @Binding var isShowing: Bool
    @Binding var showEnergyCostView: Bool
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            if isShowing {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut) {
                            isShowing = false
                        }
                    }
            }
            
            // Side menu
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack {
                        Text("Menu")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation(.easeInOut) {
                                isShowing = false
                            }
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.primary)
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 20)
                    
                    Divider()
                    
                    // Menu items
                    VStack(spacing: 0) {
                        // Devices
                        Button(action: {
                            withAnimation(.easeInOut) {
                                isShowing = false
                            }
                        }) {
                            MenuRow(title: "Devices", icon: "devices.homekit")
                        }
                        
                        // Energy Cost View
                        Button(action: {
                            withAnimation(.easeInOut) {
                                isShowing = false
                                showEnergyCostView = true
                            }
                        }) {
                            MenuRow(title: "Energy Costs", icon: "bolt.circle.fill")
                        }
                        
                        // Add more menu items as needed
                        Button(action: {
                            // Future action
                        }) {
                            MenuRow(title: "Analytics", icon: "chart.bar.fill")
                        }
                        
                        Button(action: {
                            // Future action
                        }) {
                            MenuRow(title: "Schedules", icon: "timer")
                        }
                        
                        Button(action: {
                            // Future action
                        }) {
                            MenuRow(title: "Automations", icon: "wand.and.stars")
                        }
                        
                    }
                    
                    Spacer()
                    
                    Divider()
                    
                    // Settings button at bottom
                    Button(action: {
                        // Navigate to settings
                    }) {
                        MenuRow(title: "Settings", icon: "gearshape.fill")
                    }
                    .padding(.bottom)
                }
                .frame(width: 280)
                .background(Color(.systemBackground))
                .offset(x: isShowing ? 0 : -280)
                .animation(.easeInOut(duration: 0.3), value: isShowing)
                
                Spacer()
            }
        }
        .zIndex(100)
    }
}

struct MenuRow: View {
    var title: String
    var icon: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .frame(width: 24, height: 24)
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
            
            Spacer()
        }
        .foregroundColor(.primary)
        .padding(.vertical, 12)
        .padding(.horizontal)
        .contentShape(Rectangle())
    }
}
