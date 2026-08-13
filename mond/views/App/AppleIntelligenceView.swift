//
//  AppleIntelligenceView.swift
//  mond
//

import SwiftUI

struct AppleIntelligenceView: View {
    @State private var isRunning = false
    @State private var result: AppleIntelligenceDiagnosticResult?
    @State private var latestLogURL: URL?
    @State private var logText = ""

    var body: some View {
        List {
            Section {
                Button {
                    runDiagnostic()
                } label: {
                    HStack {
                        if isRunning {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "stethoscope")
                        }

                        Text(isRunning ? "Running diagnostic…" : "Run diagnostic and prepare")
                    }
                }
                .disabled(isRunning)
            } header: {
                Label("One-click flow", systemImage: "wand.and.stars")
            } footer: {
                Text("The flow checks access, MobileGestalt, Siri feature flags and GREYMATTER eligibility, creates backups, applies the supported spoof payload, verifies the result and saves the log in Documents. A reboot and the model download still require system interaction.")
            }

            if let result {
                Section {
                    Text(result.summary)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(result.checks) { check in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: icon(for: check.status))
                                .foregroundStyle(color(for: check.status))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(check.title)
                                    .font(.headline)
                                Text(check.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                } header: {
                    Label("Result", systemImage: "checkmark.circle")
                }
            }

            Section {
                ScrollView {
                    Text(logText.isEmpty ? "Run the one-click flow to collect a diagnostic log." : logText)
                        .font(.system(size: 10, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(minHeight: 180, maxHeight: 320)
            } header: {
                Label("Diagnostic log", systemImage: "doc.text.magnifyingglass")
            } footer: {
                if let latestLogURL {
                    Text("Saved as \(latestLogURL.lastPathComponent) in the app's Documents/AppleIntelligenceDiagnostics folder.")
                        .textSelection(.enabled)
                }
            }

            if let latestLogURL {
                Section {
                    ShareLink(item: latestLogURL) {
                        Label("Export diagnostic log", systemImage: "square.and.arrow.up")
                    }
                } header: {
                    Label("Export", systemImage: "arrow.up.doc")
                }
            }

            Section {
                Text("On a base iPhone 15, this can make the eligibility and download flow visible, but Apple officially supports Apple Intelligence only on iPhone 15 Pro models and iPhone 16 or later. Full on-device features may still be blocked by hardware or server attestation.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Label("Limitations", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle("Apple Intelligence")
        .tint(Color("AccentColor"))
        .onAppear {
            loadLatestLog()
        }
    }

    private func runDiagnostic() {
        isRunning = true
        AppleIntelligenceDiagnostics.run { newResult in
            result = newResult
            latestLogURL = newResult.logURL
            logText = (try? String(contentsOf: newResult.logURL, encoding: .utf8)) ?? ""
            isRunning = false
        }
    }

    private func loadLatestLog() {
        guard let url = AppleIntelligenceLogStore.latestLogURL() else { return }
        latestLogURL = url
        logText = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    private func icon(for status: AppleIntelligenceDiagnosticStatus) -> String {
        switch status {
        case .passed:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .failed:
            return "xmark.octagon.fill"
        }
    }

    private func color(for status: AppleIntelligenceDiagnosticStatus) -> Color {
        switch status {
        case .passed:
            return .green
        case .warning:
            return .orange
        case .failed:
            return .red
        }
    }
}
