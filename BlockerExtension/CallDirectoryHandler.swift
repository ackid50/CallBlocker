import Foundation
import CallKit

class CallDirectoryHandler: CXCallDirectoryProvider {

    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        context.delegate = self
        let rules = RuleStore.load()
        let numbers = RuleExpander.expand(rules)
        for n in numbers {
            context.addBlockingEntry(withNextSequentialPhoneNumber: n)
        }
        context.completeRequest()
    }
}

extension CallDirectoryHandler: CXCallDirectoryExtensionContextDelegate {
    func requestFailed(for extensionContext: CXCallDirectoryExtensionContext, withError error: Error) {
    }
}
