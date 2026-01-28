import Foundation

enum AppDirectories {
    private static let fileManager = FileManager.default
    
    static var applicationSupport: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }
    
    static var plaidRoot: URL {
        applicationSupport.appendingPathComponent("Plaid", isDirectory: true)
    }
    
    static var models: URL {
        plaidRoot.appendingPathComponent("Models", isDirectory: true)
    }
    
    static var logs: URL {
        plaidRoot.appendingPathComponent("Logs", isDirectory: true)
    }
    
    static var history: URL {
        plaidRoot.appendingPathComponent("History", isDirectory: true)
    }
    
    static func ensureDirectoryExists(_ url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
