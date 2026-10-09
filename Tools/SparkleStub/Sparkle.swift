// Minimal stand-in for the Sparkle framework.
//
// The Chinese build must never install an upstream English release over
// itself, so the updater is compiled out instead of linked in. This module
// keeps the two call sites in the app source compiling untouched.

import Foundation

public protocol SPUUpdaterDelegate: AnyObject {}
public protocol SPUUserDriver: AnyObject {}

public final class SPUUpdater: NSObject {
    public var automaticallyChecksForUpdates: Bool = false
    public var automaticallyDownloadsUpdates: Bool = false
    public var updateCheckInterval: TimeInterval = 0
    public var feedURL: URL?
    public var canCheckForUpdates: Bool { false }

    public func start() {}
    public func checkForUpdates() {}
    public func checkForUpdates(_ sender: Any?) {}
    public func checkForUpdatesInBackground() {}
}

public final class SPUStandardUpdaterController: NSObject {
    public let updater: SPUUpdater
    public private(set) var startingUpdater: Bool

    public init(
        startingUpdater: Bool,
        updaterDelegate: SPUUpdaterDelegate?,
        userDriverDelegate: SPUUserDriver?
    ) {
        self.updater = SPUUpdater()
        self.startingUpdater = startingUpdater
        super.init()
    }

    public func startUpdater() {}
    public func checkForUpdates(_ sender: Any?) {}
}

public final class SUUpdater: NSObject {
    public static let shared = SUUpdater()
    public var automaticallyChecksForUpdates: Bool = false
    public func checkForUpdates(_ sender: Any?) {}
}
