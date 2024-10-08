//
// Copyright 2019 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

@objc
public class ContentProxy: NSObject {

    @available(*, unavailable, message: "do not instantiate this class.")
    private override init() {
    }

    @objc
    public class func sessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        let proxyHost = "contentproxy.signal.org"
        let proxyPort = 443
        configuration.connectionProxyDictionary = [
            "HTTPEnable": 1,
            "HTTPProxy": proxyHost,
            "HTTPPort": proxyPort,
            "HTTPSEnable": 1,
            "HTTPSProxy": proxyHost,
            "HTTPSPort": proxyPort
        ]
        configuration.multipathServiceType = .handover
        return configuration
    }

    public class func configureProxiedRequest(request: inout URLRequest) -> Bool {
        request.setValue(
            OWSURLSession.userAgentHeaderValueSignalIos,
            forHTTPHeaderField: OWSHttpHeaders.userAgentHeaderKey
        )

        padRequestSize(request: &request)

        return request.url?.scheme?.lowercased() == "https"
    }

    public class func padRequestSize(request: inout URLRequest) {
        let paddingLength = Int.random(in: 1...64)
        let padding = self.padding(withLength: paddingLength)
        assert(padding.count == paddingLength)
        request.setValue(padding, forHTTPHeaderField: "X-SignalPadding")
    }

    private class func padding(withLength length: Int) -> String {
        var result = ""
        for _ in 1...length {
            let value = UInt8.random(in: 48...122)
            result += String(UnicodeScalar(value))
        }
        return result
    }
}
