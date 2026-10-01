#if os(macOS) && DEBUG
import Foundation
import Security

enum CloudSyncLocalBuildSupport {
    /// Ad hoc local builds lack CloudKit entitlements and CKContainer traps before it can throw.
    /// Properly provisioned builds continue to initialize CKSyncEngine eagerly.
    static var canInitializeCloudKit: Bool {
        guard let task = SecTaskCreateFromSelf(nil),
              let services = SecTaskCopyValueForEntitlement(
                task, "com.apple.developer.icloud-services" as CFString, nil
              ) as? [String],
              let containers = SecTaskCopyValueForEntitlement(
                task, "com.apple.developer.icloud-container-identifiers" as CFString, nil
              ) as? [String] else { return false }
        return services.contains("CloudKit") && containers.contains("iCloud.app.reqeast")
    }
}
#endif
