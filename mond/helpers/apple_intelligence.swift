//
//  apple_intelligence.swift
//  mond
//
//  Apple Intelligence diagnostics and compatibility preparation.
//

import Foundation
import Darwin

enum AppleIntelligenceDiagnosticStatus: String {
    case passed = "OK"
    case warning = "WARN"
    case failed = "FAIL"
}

struct AppleIntelligenceDiagnosticCheck: Identifiable {
    let id = UUID()
    let title: String
    let status: AppleIntelligenceDiagnosticStatus
    let detail: String
}

struct AppleIntelligenceDiagnosticResult {
    let logURL: URL
    let checks: [AppleIntelligenceDiagnosticCheck]
    let summary: String
}

final class AppleIntelligenceLogSession {
    let url: URL

    private let lock = NSLock()
    private var contents = ""

    init() throws {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = documents.appendingPathComponent("AppleIntelligenceDiagnostics", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        url = directory.appendingPathComponent("diagnostic-\(stamp).log")
        FileManager.default.createFile(atPath: url.path, contents: nil)
    }

    func append(_ message: String) {
        let line = "[\(ISO8601DateFormatter().string(from: Date()))] \(message)\n"

        lock.lock()
        contents.append(line)
        lock.unlock()

        if let data = line.data(using: .utf8) {
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            }
        }
    }

    func text() -> String {
        lock.lock()
        defer { lock.unlock() }
        return contents
    }
}

enum AppleIntelligenceLogStore {
    static var directoryURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AppleIntelligenceDiagnostics", isDirectory: true)
    }

    static func latestLogURL() -> URL? {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        return urls
            .filter { $0.pathExtension == "log" }
            .sorted {
                let lhs = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                let rhs = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                return lhs > rhs
            }
            .first
    }
}

enum AppLogStore {
    private static let queue = DispatchQueue(label: "com.roooot.mond.log-store")

    static var url: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("mond.log")
    }

    static func append(_ text: String) {
        queue.async {
            guard let data = text.data(using: .utf8) else { return }
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }
            guard let handle = try? FileHandle(forWritingTo: url) else { return }
            defer { try? handle.close() }
            try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        }
    }
}

enum AppleIntelligenceDiagnostics {
    private static let aiKey = "A62OafQ85EJAiiqKn4agtg"
    private static let productTypeKey = "h9jDsbgj7xIVeIQ8S3/X3Q"

    static func run(completion: @escaping (AppleIntelligenceDiagnosticResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result: AppleIntelligenceDiagnosticResult

            do {
                let session = try AppleIntelligenceLogSession()
                result = run(session: session)
            } catch {
                let fallbackURL = AppleIntelligenceLogStore.directoryURL
                    .appendingPathComponent("diagnostic-failed-\(UUID().uuidString).log")
                try? FileManager.default.createDirectory(
                    at: AppleIntelligenceLogStore.directoryURL,
                    withIntermediateDirectories: true
                )
                let message = "Unable to create diagnostic log: \(error.localizedDescription)\n"
                try? message.data(using: .utf8)?.write(to: fallbackURL)
                result = AppleIntelligenceDiagnosticResult(
                    logURL: fallbackURL,
                    checks: [AppleIntelligenceDiagnosticCheck(
                        title: "Log storage",
                        status: .failed,
                        detail: error.localizedDescription
                    )],
                    summary: "Не удалось создать файл диагностики."
                )
            }

            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    private static func run(session: AppleIntelligenceLogSession) -> AppleIntelligenceDiagnosticResult {
        var checks: [AppleIntelligenceDiagnosticCheck] = []
        let device = machineName()
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let versionText = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"

        session.append("=== Apple Intelligence diagnostic / preparation ===")
        session.append("Device identifier: \(device)")
        session.append("iOS version: \(versionText)")
        session.append("Exploit method: \(UserDefaults.standard.string(forKey: "method") ?? "bad_query")")

        let supportedVersion = version.majorVersion == 27 && version.minorVersion == 0
        checks.append(AppleIntelligenceDiagnosticCheck(
            title: "iOS version",
            status: supportedVersion ? .passed : .warning,
            detail: supportedVersion ? "iOS 27.0 is in the supported range." : "This build is outside the README-supported iOS 27.0 beta range."
        ))
        session.append(supportedVersion ? "[OK] iOS version is in the supported range." : "[WARN] iOS version is outside the supported range.")

        let mgHandle = grant_mg()
        let mgAccess = mgHandle >= 0
        checks.append(AppleIntelligenceDiagnosticCheck(
            title: "MobileGestalt access",
            status: mgAccess ? .passed : .failed,
            detail: "sandbox handle: \(mgHandle)"
        ))
        session.append(mgAccess ? "[OK] MobileGestalt access granted (handle \(mgHandle))." : "[FAIL] MobileGestalt access failed (handle \(mgHandle)).")

        let featureFlagsHandle = grant_access(
            TweakPaths.feature_flags_dir,
            probe_leaf: "Global.plist",
            msg: "granted FeatureFlags access"
        )
        let featureFlagsAccess = featureFlagsHandle >= 0
        session.append(featureFlagsAccess ? "[OK] FeatureFlags access granted (handle \(featureFlagsHandle))." : "[WARN] FeatureFlags access unavailable (handle \(featureFlagsHandle)).")

        let eligibilityHandle = grant_access(
            TweakPaths.eligibility_dir,
            probe_leaf: "eligibility.plist",
            msg: "granted eligibility access"
        )
        let eligibilityAccess = eligibilityHandle >= 0
        session.append(eligibilityAccess ? "[OK] eligibilityd access granted (handle \(eligibilityHandle))." : "[WARN] eligibilityd access unavailable (handle \(eligibilityHandle)).")

        guard mgAccess else {
            checks.append(AppleIntelligenceDiagnosticCheck(
                title: "MobileGestalt payload",
                status: .failed,
                detail: "The exploit did not grant access, so no changes were applied."
            ))
            return finish(session: session, checks: checks, summary: "Не удалось получить доступ к MobileGestalt. Лог сохранён.")
        }

        let mgURL = URL(fileURLWithPath: TweakPaths.gestalt)
        guard let mg = try? NSMutableDictionary(contentsOf: mgURL, error: ()) else {
            session.append("[FAIL] Could not parse MobileGestalt as a property list.")
            checks.append(AppleIntelligenceDiagnosticCheck(
                title: "MobileGestalt payload",
                status: .failed,
                detail: "The plist is missing, unreadable, or invalid."
            ))
            return finish(session: session, checks: checks, summary: "MobileGestalt не удалось прочитать. Лог сохранён.")
        }

        let cacheExtra = mutableDictionary(mg["CacheExtra"])
        let currentProductType = cacheExtra[productTypeKey] as? String ?? "missing"
        let currentAIValue = cacheExtra[aiKey] as? NSNumber
        let currentAIEnabled = currentAIValue?.intValue == 1
        let regionCode = cacheExtra["h63QSdBCiT/z0WU6rdQv6Q"] as? String ?? "missing"
        let regionInfo = cacheExtra["zHeENZu+wbg7PUprwNwBWg"] as? String ?? "missing"

        session.append("MobileGestalt ProductType: \(currentProductType)")
        session.append("MobileGestalt DeviceSupportsGenerativeModelSystems (\(aiKey)): \(currentAIValue?.stringValue ?? "missing")")
        session.append("MobileGestalt region: \(regionCode) / \(regionInfo)")

        let likelyBaseIPhone15 = device == "iPhone15,4" || device == "iPhone15,5"
        let targetProductType = device.hasPrefix("iPad") ? "iPad16,3" : "iPhone16,1"
        session.append(likelyBaseIPhone15 ? "[INFO] Base iPhone 15 detected; using iPhone15 Pro ProductType for the preparation pass." : "[INFO] Using supported ProductType target: \(targetProductType).")

        let baselineURL = AppPaths.backupsURLForAppleIntelligence
        do {
            try backupIfNeeded(source: mgURL, destination: baselineURL)
            session.append("[OK] MobileGestalt backup: \(baselineURL.lastPathComponent)")
        } catch {
            session.append("[WARN] Could not create MobileGestalt backup: \(error.localizedDescription)")
        }

        cacheExtra[aiKey] = 1
        cacheExtra[productTypeKey] = targetProductType
        mg["CacheExtra"] = cacheExtra

        do {
            let data = try PropertyListSerialization.data(fromPropertyList: mg, format: .xml, options: 0)
            try atomicWrite(data, to: mgURL)

            let verified = try NSMutableDictionary(contentsOf: mgURL, error: ())
            let verifiedExtra = mutableDictionary(verified["CacheExtra"])
            let verifiedAI = (verifiedExtra[aiKey] as? NSNumber)?.intValue == 1
            let verifiedProduct = verifiedExtra[productTypeKey] as? String ?? "missing"
            let passed = verifiedAI && verifiedProduct == targetProductType

            session.append(passed ? "[OK] MobileGestalt mutation verified." : "[FAIL] MobileGestalt mutation did not verify after writing.")
            session.append("Verified ProductType: \(verifiedProduct)")
            session.append("Verified AI flag: \(verifiedAI)")
            checks.append(AppleIntelligenceDiagnosticCheck(
                title: "MobileGestalt preparation",
                status: passed ? .passed : .failed,
                detail: "ProductType=\(verifiedProduct), AI flag=\(verifiedAI)"
            ))
        } catch {
            session.append("[FAIL] MobileGestalt write failed: \(error.localizedDescription)")
            checks.append(AppleIntelligenceDiagnosticCheck(
                title: "MobileGestalt preparation",
                status: .failed,
                detail: error.localizedDescription
            ))
        }

        if featureFlagsAccess {
            let flagsURL = URL(fileURLWithPath: TweakPaths.feature_flags)
            do {
                try backupIfNeeded(source: flagsURL, destination: AppPaths.backupsURLForAppleIntelligenceFeatureFlags)
                var flags = (try? NSMutableDictionary(contentsOf: flagsURL, error: ())) ?? NSMutableDictionary()
                let siri = mutableDictionary(flags["Siri"])
                siri["sae_override"] = ["Enabled": true]
                siri["assistant_engine_override"] = ["Enabled": true]
                flags["Siri"] = siri

                let siriUI = mutableDictionary(flags["SiriUI"])
                siriUI["sae"] = ["Enabled": true]
                flags["SiriUI"] = siriUI

                let data = try PropertyListSerialization.data(fromPropertyList: flags, format: .xml, options: 0)
                try atomicWrite(data, to: flagsURL)
                session.append("[OK] Siri and SiriUI feature flags written and preserved.")
                checks.append(AppleIntelligenceDiagnosticCheck(
                    title: "Siri feature flags",
                    status: .passed,
                    detail: "Siri/sae_override, Siri/assistant_engine_override and SiriUI/sae enabled."
                ))
            } catch {
                session.append("[WARN] FeatureFlags write failed: \(error.localizedDescription)")
                checks.append(AppleIntelligenceDiagnosticCheck(
                    title: "Siri feature flags",
                    status: .warning,
                    detail: error.localizedDescription
                ))
            }
        } else {
            checks.append(AppleIntelligenceDiagnosticCheck(
                title: "Siri feature flags",
                status: .warning,
                detail: "The exploit did not grant access to /var/preferences/FeatureFlags/Global.plist."
            ))
        }

        if eligibilityAccess {
            let eligibilityURL = URL(fileURLWithPath: TweakPaths.eligibility)
            do {
                guard FileManager.default.fileExists(atPath: eligibilityURL.path) else {
                    throw AppleIntelligenceDiagnosticError.fileMissing(eligibilityURL.path)
                }

                try backupIfNeeded(source: eligibilityURL, destination: AppPaths.backupsURLForAppleIntelligenceEligibility)
                let eligibility = try NSMutableDictionary(contentsOf: eligibilityURL, error: ())
                let greyMatter = mutableDictionary(eligibility["OS_ELIGIBILITY_DOMAIN_GREYMATTER"])
                let context = mutableDictionary(greyMatter["context"])
                context["OS_ELIGIBILITY_CONTEXT_ELIGIBLE_DEVICE_LANGUAGES"] = [["en"]]
                greyMatter["context"] = context
                greyMatter["os_eligibility_answer_source_t"] = 1
                greyMatter["os_eligibility_answer_t"] = 4
                let status = mutableDictionary(greyMatter["status"])
                status["OS_ELIGIBILITY_INPUT_DEVICE_LANGUAGE"] = 3
                status["OS_ELIGIBILITY_INPUT_DEVICE_REGION_CODE"] = 3
                status["OS_ELIGIBILITY_INPUT_EXTERNAL_BOOT_DRIVE"] = 3
                status["OS_ELIGIBILITY_INPUT_GENERATIVE_MODEL_SYSTEM"] = 3
                status["OS_ELIGIBILITY_INPUT_SHARED_IPAD"] = 3
                status["OS_ELIGIBILITY_INPUT_SIRI_LANGUAGE"] = 3
                greyMatter["status"] = status
                eligibility["OS_ELIGIBILITY_DOMAIN_GREYMATTER"] = greyMatter

                let data = try PropertyListSerialization.data(fromPropertyList: eligibility, format: .xml, options: 0)
                try atomicWrite(data, to: eligibilityURL)
                session.append("[OK] GREYMATTER eligibility payload written and preserved.")
                checks.append(AppleIntelligenceDiagnosticCheck(
                    title: "GREYMATTER eligibility",
                    status: .passed,
                    detail: "Language, region and generative-model inputs are marked as evaluated."
                ))
            } catch {
                session.append("[WARN] eligibilityd write failed: \(error.localizedDescription)")
                checks.append(AppleIntelligenceDiagnosticCheck(
                    title: "GREYMATTER eligibility",
                    status: .warning,
                    detail: error.localizedDescription
                ))
            }
        } else {
            checks.append(AppleIntelligenceDiagnosticCheck(
                title: "GREYMATTER eligibility",
                status: .warning,
                detail: "The exploit did not grant access to /var/db/eligibilityd/eligibility.plist."
            ))
        }

        let regionLooksCompatible = regionCode == "US" && regionInfo == "LL/A"
        session.append(regionLooksCompatible ? "[OK] Region fields already look compatible." : "[WARN] Region fields are \(regionCode)/\(regionInfo); set device/Siri language and region to English (US) before testing.")
        checks.append(AppleIntelligenceDiagnosticCheck(
            title: "Region and language",
            status: regionLooksCompatible ? .passed : .warning,
            detail: regionLooksCompatible ? "US / LL/A" : "Current MobileGestalt region: \(regionCode) / \(regionInfo)."
        ))

        if currentAIEnabled {
            session.append("[INFO] The AI flag was already enabled; the pass also verifies and repairs ProductType/secondary gates.")
        } else {
            session.append("[INFO] The old flow had only the single AI flag set or unset; the new pass adds secondary gates.")
        }

        session.append("=== Preparation complete ===")
        session.append("A reboot is required before Settings can re-read these values.")
        session.append("After the model download, do not apply the original MobileGestalt backup over the AI-enabled file.")

        let hasFailure = checks.contains { $0.status == .failed }
        let hasWarning = checks.contains { $0.status == .warning }
        let summary: String
        if hasFailure {
            summary = "Подготовка завершилась с ошибкой. Откройте лог и отправьте его вместе с версией iOS и моделью устройства."
        } else if hasWarning {
            summary = "Подготовка завершена с предупреждениями. Перезагрузите устройство и проверьте Apple Intelligence в Settings."
        } else {
            summary = "Подготовка завершена. Перезагрузите устройство; затем Apple Intelligence должен повторно проверить eligibility."
        }

        return finish(session: session, checks: checks, summary: summary)
    }

    private static func finish(
        session: AppleIntelligenceLogSession,
        checks: [AppleIntelligenceDiagnosticCheck],
        summary: String
    ) -> AppleIntelligenceDiagnosticResult {
        session.append("Summary: \(summary)")
        session.append("Log file: \(session.url.path)")
        return AppleIntelligenceDiagnosticResult(logURL: session.url, checks: checks, summary: summary)
    }

    private static func mutableDictionary(_ value: Any?) -> NSMutableDictionary {
        if let dictionary = value as? NSMutableDictionary {
            return dictionary
        }
        if let dictionary = value as? NSDictionary {
            return NSMutableDictionary(dictionary: dictionary)
        }
        if let dictionary = value as? [String: Any] {
            return NSMutableDictionary(dictionary: dictionary)
        }
        return NSMutableDictionary()
    }

    private static func backupIfNeeded(source: URL, destination: URL) throws {
        guard FileManager.default.fileExists(atPath: source.path),
              !FileManager.default.fileExists(atPath: destination.path) else {
            return
        }
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: source, to: destination)
    }

    private static func atomicWrite(_ data: Data, to target: URL) throws {
        let temp = target.deletingLastPathComponent()
            .appendingPathComponent(".mond-\(target.lastPathComponent)-\(UUID().uuidString).tmp")
        try data.write(to: temp, options: [.withoutOverwriting])
        defer { try? FileManager.default.removeItem(at: temp) }

        if FileManager.default.fileExists(atPath: target.path) {
            _ = try FileManager.default.replaceItemAt(target, withItemAt: temp)
        } else {
            try FileManager.default.moveItem(at: temp, to: target)
        }
    }

    private static func machineName() -> String {
        var sysInfo = utsname()
        uname(&sysInfo)
        return Mirror(reflecting: sysInfo.machine).children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
    }
}

private enum AppleIntelligenceDiagnosticError: LocalizedError {
    case fileMissing(String)

    var errorDescription: String? {
        switch self {
        case .fileMissing(let path):
            return "File is missing: \(path)"
        }
    }
}

extension AppPaths {
    fileprivate static var aiBackupDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AppleIntelligenceBackups", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    fileprivate static var backupsURLForAppleIntelligence: URL {
        aiBackupDirectory.appendingPathComponent("MobileGestalt.plist")
    }

    fileprivate static var backupsURLForAppleIntelligenceFeatureFlags: URL {
        aiBackupDirectory.appendingPathComponent("FeatureFlags-Global.plist")
    }

    fileprivate static var backupsURLForAppleIntelligenceEligibility: URL {
        aiBackupDirectory.appendingPathComponent("eligibility.plist")
    }
}
