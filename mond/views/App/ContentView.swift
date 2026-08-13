//
//  ContentView.swift
//  mond
//
//  Created by ruter on 17.07.26.
//

import SwiftUI
import PartyUI

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @AppStorage("method") private var method: String = "bad_query"
    
    @State private var is_valid: Bool = false
    @State private var show_settings: Bool = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    LogView()
                        .modifier(TerminalPlatter())
                } header: {
                    Label("Logs", systemImage: "apple.terminal")
                }
                
                Section {
                    NavigationLink {
                        GestaltView()
                    } label: {
                        Text("MobileGestalt")
                    }
                    
                    NavigationLink {
                        PosterView()
                    } label: {
                        Text("PosterBoard")
                    }
                    .disabled(method == "cmg")
                } header: {
                    Label("Tweaks", systemImage: "paintbrush")
                } footer: {
                    if method == "cmg" {
                         Text("Only MobileGestalt is available when method is set to cmg.\nPosterBoard is still in development and may not work as expected.")
                    } else {
                        Text("PosterBoard is still in development and may not work as expected.")
                    }
                }

                Section {
                    NavigationLink {
                        AppleIntelligenceView()
                    } label: {
                        Label("Apple Intelligence", systemImage: "sparkles")
                    }
                } header: {
                    Label("Diagnostics", systemImage: "stethoscope")
                } footer: {
                    Text("Use the one-click flow to prepare Apple Intelligence spoofing and export a complete diagnostic log.")
                }
            }
            .navigationTitle("mond")
            .tint(Color("AccentColor"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button {
                            show_settings = true
                        } label: {
                            Image(systemName: "gear")
                        }
                    }
                }
            }
            .sheet(isPresented: $show_settings) {
                SettingsView()
            }
        }
    }
}
