//
//  apple_intelligence.swift
//  mond
//
//  Apple Intelligence diagnostics and compatibility preparation.
//

import Foundation
import Darwin
#if canImport(FoundationModels)
import FoundationModels
#endif

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
        let directory = AppleIntelligenceLogStore.directoryURL
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
                handle.synchronizeFile()
            }
        }
    }

    func synchronize() {
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        handle.synchronizeFile()
    }

    func text() -> String {
        lock.lock()
        defer { lock.unlock() }
        return contents
    }
}

enum AppleIntelligenceLogStore {
    static var appDirectoryURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = documents.appendingPathComponent("mond", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static var directoryURL: URL {
        appDirectoryURL
            .appendingPathComponent("AppleIntelligenceDiagnostics", isDirectory: true)
    }

    private static var legacyDirectoryURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AppleIntelligenceDiagnostics", isDirectory: true)
    }

    static func latestLogURL() -> URL? {
        let urls = [directoryURL, legacyDirectoryURL].flatMap { directory in
            (try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )) ?? []
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

    static func synchronize(_ url: URL) {
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        handle.synchronizeFile()
    }
}

enum AppLogStore {
    private static let queue = DispatchQueue(label: "com.roooot.mond.log-store")

    static var url: URL {
        AppleIntelligenceLogStore.appDirectoryURL
            .appendingPathComponent("mond.log")
    }

    static func append(_ text: String) {
        queue.async {
            guard let data = text.data(using: .utf8) else { return }
            try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }
            guard let handle = try? FileHandle(forWritingTo: url) else { return }
            defer { try? handle.close() }
            try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        }
    }

    static func flush() {
        queue.sync { }
        AppleIntelligenceLogStore.synchronize(url)
    }
}

enum AppleIntelligenceDiagnostics {
    private static let aiKey = "A62OafQ85EJAiiqKn4agtg"
    private static let productTypeKey = "h9jDsbgj7xIVeIQ8S3/X3Q"
    private static let hardwareModelKey = "oYicEKzVTz4/CxxE05pEgQ"
    private static let cpuChipKey = "5pYKlGnYYBzGvAlIU8RjEQ"

    // iOS 27 consumers read more than the classic ProductType answer. Keep
    // the identity internally consistent so eligibility and Siri do not see
    // an iPhone 16 ProductType next to iPhone 15 component mirrors.
    private static let productTypeMirrorKeys = [
        "+1TeoctsaQC55zwHZ6MESg", // ProductTypeDescForAudio
        "0+nc/Udy4WNG8S+Q7a/s1A", // ThinningProductType
        "G91h5IuJvXISeyngNFqEpg", // ProductTypeDescForUserVisibility
        "GEsznZwAYGOa1a67QU1Uew", // ProductTypeDescForPowerPerf
        "GqAdWRLnC7oYQrNYF48VYA", // SubProductType
        "MKE8hwsOxxRCtwBk2aDBZA", // ProductTypeDescForAutomatedTesting
        "myx96YOqBSDzLwljSYWBiQ", // ProductTypeDescForCamera
        "xNN67KktpWp7syTT3S1BFA"  // ProductTypeDescForAnalytics
    ]

    private static let hardwareModelMirrorKeys = [
        "/YYygAofPDbhrwToVsXdeA", // HWModelStr
        "GGIIDN/ANr8X2WrgS6nBYQ", // HWModelUniqueStr
        "ZGraRMW0TsxCvONeeJ5C2w", // HWModelDescriptionForUserVisibility
        "b4e7mEbjqfewD6oXmo9U5g", // HWModelDescriptionForPowerPerf
        "dW5fpt/6HhaTbnK/UqL6cA", // HWModelDescriptionForAudio
        "oQNDePXjSD1z7W0ddqt9tg", // HWModelDescriptionForAutomatedTesting
        "uCIk6n9Am5fsV2cTjhqFQw", // HWModelDescriptionForAnalytics
        "yAfB6E2v0++rHtdW7SDg8w"  // HWModelDescriptionForCamera
    ]

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
        session.append("Application log directory: \(AppleIntelligenceLogStore.appDirectoryURL.path)")

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
            msg: "granted FeatureFlags access",
            allow_missing: true
        )
        let featureFlagsAccess = featureFlagsHandle >= 0
        session.append(featureFlagsAccess ? "[OK] FeatureFlags access granted (handle \(featureFlagsHandle), create-if-missing)." : "[WARN] FeatureFlags access unavailable (handle \(featureFlagsHandle)).")

        var eligibilityTarget: (file: String, directory: String)?
        for candidate in TweakPaths.eligibility_candidates {
            let handle = grant_access(
                candidate.directory,
                probe_leaf: "eligibility.plist",
                msg: "granted eligibility access for \(candidate.file)",
                allow_missing: true
            )
            if handle >= 0 {
                eligibilityTarget = candidate
                session.append("[OK] eligibility access granted for \(candidate.file) (handle \(handle), create-if-missing).")
                break
            }
            session.append("[WARN] eligibility path unavailable: \(candidate.file) (handle \(handle)).")
        }

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
        let targetHardwareModel = device.hasPrefix("iPad") ? "J717AP" : "D83AP"
        let targetCPUChip = "t8130"
        session.append(likelyBaseIPhone15 ? "[INFO] Base iPhone 15 detected; using iPhone15 Pro identity for the preparation pass." : "[INFO] Using supported ProductType target: \(targetProductType).")

        let baselineURL = AppPaths.backupsURLForAppleIntelligence
        do {
            try backupIfNeeded(source: mgURL, destination: baselineURL)
            session.append("[OK] MobileGestalt backup: \(baselineURL.lastPathComponent)")
        } catch {
            session.append("[WARN] Could not create MobileGestalt backup: \(error.localizedDescription)")
        }

        cacheExtra[aiKey] = 1
        cacheExtra[productTypeKey] = targetProductType
        cacheExtra[hardwareModelKey] = targetHardwareModel
        cacheExtra[cpuChipKey] = targetCPUChip
        if device.hasPrefix("iPhone") {
            for key in productTypeMirrorKeys { cacheExtra[key] = targetProductType }
            for key in hardwareModelMirrorKeys { cacheExtra[key] = targetHardwareModel }
            session.append("[INFO] Applying iOS 27 identity mirrors: ProductType=\(productTypeMirrorKeys.count), HWModel=\(hardwareModelMirrorKeys.count).")
        }
        mg["CacheExtra"] = cacheExtra

        do {
            let data = try PropertyListSerialization.data(fromPropertyList: mg, format: .xml, options: 0)
            try atomicWrite(data, to: mgURL)

            let verified = try NSMutableDictionary(contentsOf: mgURL, error: ())
            let verifiedExtra = mutableDictionary(verified["CacheExtra"])
            let verifiedAI = (verifiedExtra[aiKey] as? NSNumber)?.intValue == 1
            let verifiedProduct = verifiedExtra[productTypeKey] as? String ?? "missing"
            let verifiedHardware = verifiedExtra[hardwareModelKey] as? String ?? "missing"
            let verifiedCPU = verifiedExtra[cpuChipKey] as? String ?? "missing"
            let productMirrorsVerified = device.hasPrefix("iPhone") && productTypeMirrorKeys.allSatisfy {
                (verifiedExtra[$0] as? String) == targetProductType
            }
            let hardwareMirrorsVerified = device.hasPrefix("iPhone") && hardwareModelMirrorKeys.allSatisfy {
                (verifiedExtra[$0] as? String) == targetHardwareModel
            }
            let identityVerified = !device.hasPrefix("iPhone") || (productMirrorsVerified && hardwareMirrorsVerified)
            let passed = verifiedAI && verifiedProduct == targetProductType && verifiedHardware == targetHardwareModel && verifiedCPU == targetCPUChip && identityVerified

            session.append(passed ? "[OK] MobileGestalt mutation verified." : "[FAIL] MobileGestalt mutation did not verify after writing.")
            session.append("Verified ProductType: \(verifiedProduct)")
            session.append("Verified HardwareModel: \(verifiedHardware)")
            session.append("Verified CPUChip: \(verifiedCPU)")
            if device.hasPrefix("iPhone") {
                session.append("Verified identity mirrors: ProductType=\(productMirrorsVerified), HWModel=\(hardwareMirrorsVerified)")
            }
            session.append("Verified AI flag: \(verifiedAI)")
            checks.append(AppleIntelligenceDiagnosticCheck(
                title: "MobileGestalt preparation",
                status: passed ? .passed : .failed,
                detail: "ProductType=\(verifiedProduct), HWModel=\(verifiedHardware), CPU=\(verifiedCPU), AI flag=\(verifiedAI), mirrors=\(identityVerified)"
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
                try FileManager.default.createDirectory(
                    at: flagsURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
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

        if let eligibilityTarget {
            let eligibilityURL = URL(fileURLWithPath: eligibilityTarget.file)
            do {
                try FileManager.default.createDirectory(
                    at: eligibilityURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try backupIfNeeded(source: eligibilityURL, destination: AppPaths.backupsURLForAppleIntelligenceEligibility)
                let eligibility = (try? NSMutableDictionary(contentsOf: eligibilityURL, error: ())) ?? NSMutableDictionary()
                session.append(FileManager.default.fileExists(atPath: eligibilityURL.path) ? "[INFO] Existing eligibility plist loaded." : "[INFO] Eligibility plist is missing; creating a new payload.")
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
                    detail: "Language, region and generative-model inputs are marked as evaluated at \(eligibilityTarget.file)."
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
                detail: "The exploit could not grant access to either known eligibility plist path."
            ))
        }

        if let cString = apple_intelligence_refresh_availability() {
            let refreshResult = String(cString: cString)
            free(cString)
            for line in refreshResult.split(separator: "\n") {
                session.append("[GMS] \(line)")
            }
            let refreshCompleted = refreshResult.contains("availability.update.sent=1 callback=1 timeout=0")
            checks.append(AppleIntelligenceDiagnosticCheck(
                title: "GenerativeModels availability refresh",
                status: refreshCompleted ? .passed : .warning,
                detail: refreshCompleted
                    ? "GMAvailabilityWrapper completed its availability refresh."
                    : "GMAvailabilityWrapper refresh did not complete synchronously; inspect the saved log."
            ))
        } else {
            checks.append(AppleIntelligenceDiagnosticCheck(
                title: "GenerativeModels availability refresh",
                status: .warning,
                detail: "The availability refresh returned no diagnostic data."
            ))
        }

        checks.append(recordRuntimeProbe(session: session))

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
        session.append("A respring is required before SpringBoard and Settings can re-read these values.")
        session.append("After the model download, do not apply the original MobileGestalt backup over the AI-enabled file.")

        let hasFailure = checks.contains { $0.status == .failed }
        let hasWarning = checks.contains { $0.status == .warning }
        let summary: String
        if hasFailure {
            summary = "Подготовка завершилась с ошибкой. Откройте лог и отправьте его вместе с версией iOS и моделью устройства."
        } else if hasWarning {
            summary = "Подготовка завершена с предупреждениями. Выполните respring и проверьте Apple Intelligence в Settings."
        } else {
            summary = "Подготовка завершена. Сейчас будет выполнен respring; затем Apple Intelligence должен повторно проверить eligibility."
        }

        return finish(session: session, checks: checks, summary: summary)
    }

    static func captureRuntime(completion: @escaping (AppleIntelligenceDiagnosticResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result: AppleIntelligenceDiagnosticResult
            do {
                let session = try AppleIntelligenceLogSession()
                session.append("=== Apple Intelligence post-respring runtime snapshot ===")
                session.append("Device identifier: \(machineName())")
                let version = ProcessInfo.processInfo.operatingSystemVersion
                session.append("iOS version: \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)")
                session.append("No MobileGestalt write, preference write, or respring was requested.")
                let check = recordRuntimeProbe(session: session)
                result = finish(session: session, checks: [check], summary: check.status == .passed
                    ? "Текущий Siri runtime сообщает, что SAE включён."
                    : "Снимок сохранён: downstream Siri generation gate всё ещё требует проверки.")
            } catch {
                let fallbackURL = AppleIntelligenceLogStore.directoryURL
                    .appendingPathComponent("runtime-failed-\(UUID().uuidString).log")
                try? FileManager.default.createDirectory(at: AppleIntelligenceLogStore.directoryURL, withIntermediateDirectories: true)
                let message = "Unable to create runtime snapshot: \(error.localizedDescription)\n"
                try? message.data(using: .utf8)?.write(to: fallbackURL)
                result = AppleIntelligenceDiagnosticResult(
                    logURL: fallbackURL,
                    checks: [AppleIntelligenceDiagnosticCheck(title: "Log storage", status: .failed, detail: error.localizedDescription)],
                    summary: "Не удалось сохранить runtime snapshot."
                )
            }
            DispatchQueue.main.async { completion(result) }
        }
    }

    static func applySiriAvailability(completion: @escaping (AppleIntelligenceDiagnosticResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result: AppleIntelligenceDiagnosticResult
            do {
                let session = try AppleIntelligenceLogSession()
                session.append("=== Apply SiriAvailability after respring ===")
                session.append("This is a controlled preference write; no respring is requested.")
                guard let cString = apple_intelligence_apply_siri_availability() else {
                    session.append("[FAIL] SiriAvailability setter returned no data.")
                    let check = AppleIntelligenceDiagnosticCheck(title: "SiriAvailability write", status: .failed, detail: "The setter returned no data.")
                    result = finish(session: session, checks: [check], summary: "Не удалось применить SiriAvailability.")
                    DispatchQueue.main.async { completion(result) }
                    return
                }
                let writeResult = String(cString: cString)
                free(cString)
                for line in writeResult.split(separator: "\n") {
                    session.append("[WRITE] \(line)")
                }
                let readbackOK = writeResult.contains("readbackEqual=1")
                let writeCheck = AppleIntelligenceDiagnosticCheck(
                    title: "SiriAvailability write",
                    status: readbackOK ? .passed : .warning,
                    detail: readbackOK ? "The patched capability dictionary was read back unchanged." : "The write did not verify with readbackEqual=1."
                )
                if let refreshCString = apple_intelligence_refresh_availability() {
                    let refreshResult = String(cString: refreshCString)
                    free(refreshCString)
                    for line in refreshResult.split(separator: "\n") {
                        session.append("[GMS] \(line)")
                    }
                }
                let runtimeCheck = recordRuntimeProbe(session: session)
                result = finish(
                    session: session,
                    checks: [writeCheck, runtimeCheck],
                    summary: readbackOK
                        ? "SiriAvailability применён. Сразу проверьте Writing Tools/Image Playground, затем сохраните runtime snapshot."
                        : "SiriAvailability не прошёл readback-проверку."
                )
            } catch {
                let fallbackURL = AppleIntelligenceLogStore.directoryURL
                    .appendingPathComponent("siri-availability-failed-\(UUID().uuidString).log")
                try? FileManager.default.createDirectory(at: AppleIntelligenceLogStore.directoryURL, withIntermediateDirectories: true)
                let message = "Unable to apply SiriAvailability: \(error.localizedDescription)\n"
                try? message.data(using: .utf8)?.write(to: fallbackURL)
                result = AppleIntelligenceDiagnosticResult(
                    logURL: fallbackURL,
                    checks: [AppleIntelligenceDiagnosticCheck(title: "SiriAvailability write", status: .failed, detail: error.localizedDescription)],
                    summary: "Не удалось применить SiriAvailability."
                )
            }
            DispatchQueue.main.async { completion(result) }
        }
    }

    private static func recordRuntimeProbe(session: AppleIntelligenceLogSession) -> AppleIntelligenceDiagnosticCheck {
        // This is intentionally read-only. It records the state consumed by
        // the Siri runtime instead of treating visible UI or a 7 GB download
        // as proof that generation is enabled.
        guard let cString = apple_intelligence_runtime_probe() else {
            session.append("[WARN] Siri runtime probe returned no data.")
            return AppleIntelligenceDiagnosticCheck(
                title: "Siri generation gate",
                status: .warning,
                detail: "The read-only AssistantServices probe returned no data."
            )
        }

        let runtime = String(cString: cString)
        free(cString)
        for line in runtime.split(separator: "\n") {
            session.append("[RUNTIME] \(line)")
        }
        recordFoundationModelAvailability(session: session)
        let saeEnabled = runtime.contains("runtime.SAE=1")
        let availabilityHasSAE = runtime.contains("availability.saeCapabilities=55") || runtime.contains("availability.saeCapabilities=0x37")
        let externalServiceDisabled = runtime.contains("external.AF.service.SAE=0")
        if externalServiceDisabled {
            session.append("[WARN] The external Siri capability service still reports SAE disabled; local SiriAvailability is not enough to enable Writing Tools.")
        }
        return AppleIntelligenceDiagnosticCheck(
            title: "Siri generation gate",
            status: saeEnabled && availabilityHasSAE ? .passed : .warning,
            detail: saeEnabled && availabilityHasSAE
                ? (externalServiceDisabled
                    ? "The local Siri runtime reports SAE enabled, but the external Siri capability service still reports SAE disabled."
                    : "The local Siri runtime reports SAE enabled.")
                : "UI/assets may be present, but the local Siri runtime still reports the SAE gate or capability word as disabled."
        )
    }

    private static func recordFoundationModelAvailability(session: AppleIntelligenceLogSession) {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let availability = SystemLanguageModel.default.availability
            let description = String(describing: availability)
            session.append("[MODEL] FoundationModels availability: \(description)")
            if description.contains("available") && !description.contains("unavailable") {
                session.append("[OK] FoundationModels reports the on-device model available.")
            } else if description.contains("modelNotReady") {
                session.append("[WARN] FoundationModels reports modelNotReady; storage usage alone does not prove activation is complete.")
            } else if description.contains("deviceNotEligible") {
                session.append("[FAIL] FoundationModels reports deviceNotEligible; this is a downstream hardware/policy gate.")
            } else if description.contains("appleIntelligenceNotEnabled") {
                session.append("[WARN] FoundationModels reports Apple Intelligence disabled.")
            } else {
                session.append("[WARN] FoundationModels reports an unavailable state: \(description).")
            }
        } else {
            session.append("[MODEL] FoundationModels requires iOS 26 or later.")
        }
#else
        session.append("[MODEL] FoundationModels framework is not present in this SDK; model availability was not queried.")
#endif
    }

    private static func finish(
        session: AppleIntelligenceLogSession,
        checks: [AppleIntelligenceDiagnosticCheck],
        summary: String
    ) -> AppleIntelligenceDiagnosticResult {
        session.append("Summary: \(summary)")
        session.append("Log file: \(session.url.path)")
        session.synchronize()
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
