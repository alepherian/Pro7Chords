import Foundation
import os.log

// MARK: - Application Logger
struct AppLogger {
    
    // MARK: - Log Categories
    private static let subsystem = "com.pro7chords.app"
    
    private static let general = OSLog(subsystem: subsystem, category: "general")
    private static let fileOperations = OSLog(subsystem: subsystem, category: "file-operations")
    private static let chordProcessing = OSLog(subsystem: subsystem, category: "chord-processing")
    private static let protobuf = OSLog(subsystem: subsystem, category: "protobuf")
    private static let coreData = OSLog(subsystem: subsystem, category: "core-data")
    
    // MARK: - Log Levels
    
    /// Logs general information
    static func info(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        let logger = getLogger(for: category)
        let location = "\(URL(fileURLWithPath: file).lastPathComponent):\(line) \(function)"
        
        if #available(macOS 11.0, *) {
            logger.info("\(message, privacy: .public) [\(location, privacy: .public)]")
        } else {
            os_log(.info, log: logger, "%{public}@ [%{public}@]", message, location)
        }
        
        // Also print to console for development
        #if DEBUG
        print("[INFO] \(message) [\(location)]")
        #endif
    }
    
    /// Logs warning messages
    static func warning(_ message: String, error: Error? = nil, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        let logger = getLogger(for: category)
        let location = "\(URL(fileURLWithPath: file).lastPathComponent):\(line) \(function)"
        let fullMessage = error != nil ? "\(message): \(error!.localizedDescription)" : message
        
        if #available(macOS 11.0, *) {
            logger.warning("\(fullMessage, privacy: .public) [\(location, privacy: .public)]")
        } else {
            os_log(.error, log: logger, "%{public}@ [%{public}@]", fullMessage, location)
        }
        
        // Also print to console for development
        #if DEBUG
        print("[WARNING] \(fullMessage) [\(location)]")
        #endif
    }
    
    /// Logs error messages
    static func error(_ message: String, error: Error, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        let logger = getLogger(for: category)
        let location = "\(URL(fileURLWithPath: file).lastPathComponent):\(line) \(function)"
        let fullMessage = "\(message): \(error.localizedDescription)"
        
        if #available(macOS 11.0, *) {
            logger.error("\(fullMessage, privacy: .public) [\(location, privacy: .public)]")
        } else {
            os_log(.error, log: logger, "%{public}@ [%{public}@]", fullMessage, location)
        }
        
        // Also print to console for development
        #if DEBUG
        print("[ERROR] \(fullMessage) [\(location)]")
        #endif
    }
    
    /// Logs debug messages (only in debug builds)
    static func debug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let logger = getLogger(for: category)
        let location = "\(URL(fileURLWithPath: file).lastPathComponent):\(line) \(function)"
        
        if #available(macOS 11.0, *) {
            logger.debug("\(message, privacy: .public) [\(location, privacy: .public)]")
        } else {
            os_log(.debug, log: logger, "%{public}@ [%{public}@]", message, location)
        }
        
        print("[DEBUG] \(message) [\(location)]")
        #endif
    }
    
    /// Logs verbose debug information (only for detailed debugging)
    static func trace(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let location = "\(URL(fileURLWithPath: file).lastPathComponent):\(line) \(function)"
        print("[TRACE] \(message) [\(location)]")
        #endif
    }
    
    // MARK: - Specialized Logging Methods
    
    /// Logs file operation events
    static func fileOperation(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        info(message, category: .fileOperations, file: file, function: function, line: line)
    }
    
    /// Logs chord processing events
    static func chordProcessing(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        info(message, category: .chordProcessing, file: file, function: function, line: line)
    }
    
    /// Logs protobuf processing events
    static func protobuf(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message, category: .protobuf, file: file, function: function, line: line)
    }
    
    /// Logs Core Data events
    static func coreData(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        info(message, category: .coreData, file: file, function: function, line: line)
    }
    
    // MARK: - Performance Logging
    
    /// Measures and logs execution time of a block
    static func measureTime<T>(_ label: String, category: LogCategory = .general, operation: () throws -> T) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            debug("⏱️ \(label) completed in \(String(format: "%.3f", timeElapsed))s", category: category)
        }
        return try operation()
    }
    
    /// Measures and logs execution time of an async block
    static func measureTime<T>(_ label: String, category: LogCategory = .general, operation: () async throws -> T) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            debug("⏱️ \(label) completed in \(String(format: "%.3f", timeElapsed))s", category: category)
        }
        return try await operation()
    }
    
    // MARK: - Helper Methods
    
    private static func getLogger(for category: LogCategory) -> OSLog {
        switch category {
        case .general: return general
        case .fileOperations: return fileOperations
        case .chordProcessing: return chordProcessing
        case .protobuf: return protobuf
        case .coreData: return coreData
        }
    }
}

// MARK: - Log Category
extension AppLogger {
    enum LogCategory {
        case general
        case fileOperations
        case chordProcessing
        case protobuf
        case coreData
    }
}

// MARK: - Convenience Extensions
extension Error {
    
    /// Logs this error with context
    func logError(_ message: String, category: AppLogger.LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        AppLogger.error(message, error: self, category: category, file: file, function: function, line: line)
    }
}

// MARK: - Debug Helpers
extension AppLogger {
    
    /// Logs memory usage information
    static func logMemoryUsage(_ label: String = "Memory Usage") {
        #if DEBUG
        let memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let memoryUsage = memoryInfo.resident_size / (1024 * 1024)
            debug("💾 \(label): \(memoryUsage) MB")
        }
        #endif
    }
    
    /// Logs system information on app startup
    static func logSystemInfo() {
        #if DEBUG
        let processInfo = ProcessInfo.processInfo
        info("🚀 Pro7Chords starting up")
        info("📱 System: \(processInfo.operatingSystemVersionString)")
        info("🧠 Physical Memory: \(processInfo.physicalMemory / (1024 * 1024)) MB")
        info("⚡ Processor Count: \(processInfo.processorCount)")
        #endif
    }
}

// MARK: - Mach Task Basic Info (for memory logging)
#if DEBUG
private struct mach_task_basic_info {
    var virtual_size: mach_vm_size_t = 0
    var resident_size: mach_vm_size_t = 0
    var resident_size_max: mach_vm_size_t = 0
    var user_time: time_value_t = time_value_t()
    var system_time: time_value_t = time_value_t()
    var policy: policy_t = 0
    var suspend_count: integer_t = 0
}
#endif
