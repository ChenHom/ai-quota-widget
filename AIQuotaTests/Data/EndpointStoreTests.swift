import Testing
import Foundation
@testable import AIQuota

struct EndpointStoreTests {
    
    private func makeStore() -> EndpointStore {
        // 使用 in-memory UserDefaults
        let suiteName = "test.endpoint.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return EndpointStore(defaults: defaults)
    }
    
    @Test func testValidHTTPSEndpoint() {
        let store = makeStore()
        let url = store.validateEndpoint("https://quota.example.com/quota.json")
        #expect(url != nil)
        #expect(url?.scheme == "https")
    }
    
    @Test func testRejectHTTPEndpoint() {
        let store = makeStore()
        let url = store.validateEndpoint("http://quota.example.com/quota.json")
        #expect(url == nil)
    }
    
    @Test func testRejectNoHostEndpoint() {
        let store = makeStore()
        let url = store.validateEndpoint("https://")
        #expect(url == nil)
    }
    
    @Test func testRejectEmptyString() {
        let store = makeStore()
        let url = store.validateEndpoint("")
        #expect(url == nil)
    }
    
    @Test func testRejectNonURLString() {
        let store = makeStore()
        let url = store.validateEndpoint("not a url")
        #expect(url == nil)
    }
    
    @Test func testSaveAndLoad() {
        let store = makeStore()
        
        // 初始為 nil
        #expect(store.loadEndpoint() == nil)
        
        // 儲存
        let saved = store.saveEndpoint("https://quota.example.com/quota.json")
        #expect(saved != nil)
        
        // 讀取
        let loaded = store.loadEndpoint()
        #expect(loaded?.absoluteString == "https://quota.example.com/quota.json")
    }
    
    @Test func testSaveRejectsInvalidURL() {
        let store = makeStore()
        let saved = store.saveEndpoint("http://not-https.com")
        #expect(saved == nil)
        #expect(store.loadEndpoint() == nil)
    }
    
    @Test func testClearEndpoint() {
        let store = makeStore()
        store.saveEndpoint("https://quota.example.com/quota.json")
        #expect(store.loadEndpoint() != nil)
        
        store.clearEndpoint()
        #expect(store.loadEndpoint() == nil)
    }
    
    @Test func testDisplayableEndpointHidesQueryAndFragment() {
        let store = makeStore()
        let url = URL(string: "https://example.com/path?token=secret&key=value#section")!
        let displayed = store.displayableEndpoint(url)
        
        #expect(!displayed.contains("secret"))
        #expect(!displayed.contains("key=value"))
        #expect(!displayed.contains("section"))
        #expect(displayed.contains("example.com/path"))
    }
}
