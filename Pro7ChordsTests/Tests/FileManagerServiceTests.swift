import XCTest
@testable import Pro7Chords

final class FileManagerServiceTests: XCTestCase {
    var fileManager: FileManagerService!
    
    @MainActor
    override func setUp() {
        super.setUp()
        fileManager = FileManagerService()
    }
    
    override func tearDown() {
        fileManager = nil
        super.tearDown()
    }
    
    // MARK: - Recent Files Tests
    @MainActor
    func testAddRecentFile() {
        let url = URL(fileURLWithPath: "/tmp/test.txt")
        fileManager.addRecentFile(url)
        
        XCTAssertEqual(fileManager.recentFiles.count, 1)
        XCTAssertEqual(fileManager.recentFiles.first?.url, url)
    }
    
    @MainActor
    func testRemoveRecentFile() {
        let url = URL(fileURLWithPath: "/tmp/test.txt")
        fileManager.addRecentFile(url)
        
        guard let file = fileManager.recentFiles.first else {
            XCTFail("Recent file not added")
            return
        }
        
        fileManager.removeRecentFile(file)
        XCTAssertTrue(fileManager.recentFiles.isEmpty)
    }
    
    @MainActor
    func testRecentFilesLimit() {
        // Add more than the limit
        for i in 1...15 {
            let url = URL(fileURLWithPath: "/tmp/test\(i).txt")
            fileManager.addRecentFile(url)
        }
        
        XCTAssertLessThanOrEqual(fileManager.recentFiles.count, 10)
        XCTAssertEqual(fileManager.recentFiles.first?.url.lastPathComponent, "test15.txt")
    }
    
    @MainActor
    func testDuplicateRecentFiles() {
        let url = URL(fileURLWithPath: "/tmp/test.txt")
        fileManager.addRecentFile(url)
        fileManager.addRecentFile(url) // Add same file again
        
        XCTAssertEqual(fileManager.recentFiles.count, 1)
    }
    
    @MainActor
    func testClearRecentFiles() {
        let url1 = URL(fileURLWithPath: "/tmp/test1.txt")
        let url2 = URL(fileURLWithPath: "/tmp/test2.txt")
        
        fileManager.addRecentFile(url1)
        fileManager.addRecentFile(url2)
        fileManager.clearRecentFiles()
        
        XCTAssertTrue(fileManager.recentFiles.isEmpty)
    }
    
    // MARK: - File Loading Tests
    @MainActor
    func testLoadNonExistentFile() async {
        let url = URL(fileURLWithPath: "/tmp/nonexistent.txt")
        
        do {
            _ = try await fileManager.loadFile(from: url)
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertTrue(error is FileManagerError)
        }
    }
    
    // MARK: - Error Handling Tests
    func testFileManagerErrorDescriptions() {
        let errors: [FileManagerError] = [
            .fileNotFound,
            .loadFailed("test message"),
            .saveFailed("test message"),
            .invalidProPresenterFormat("test format"),
            .noOriginalFile,
            .unsupportedFileType
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
    }
}
