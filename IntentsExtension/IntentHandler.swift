import Intents
import Foundation

@available(macOS 11.0, *)
class IntentHandler: INExtension {
    
    override func handler(for intent: INIntent) -> Any? {
        switch intent {
        case is ComposePDFIntent:
            return ComposePDFIntentHandler()
            
        case is BatchProcessIntent:
            return BatchProcessIntentHandler()
            
        case is ExportPDFIntent:
            return ExportPDFIntentHandler()
            
        default:
            // Return nil for unsupported intents
            return nil
        }
    }
    
    override func handlerForIntent(_ intent: INIntent) -> Any? {
        // iOS compatibility method - delegate to handler(for:)
        return handler(for: intent)
    }
}

// MARK: - Extension Supporting Classes

@available(macOS 11.0, *)
extension IntentHandler {
    
    /// Provides centralized logging for the extension
    static func log(_ message: String, level: LogLevel = .info) {
        let timestamp = DateFormatter().string(from: Date())
        print("[\(timestamp)] [IntentsExtension] [\(level.rawValue)] \(message)")
    }
    
    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }
}