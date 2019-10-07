//
//  DriverInfo.swift
//  Mr. Puppet Hub
//
//  Created by Edward Wellbrook on 04/10/2019.
//  Copyright © 2019 Thinko LLC. All rights reserved.
//

import Foundation

struct DriverInfo {

    private init() {}

    static var isDriverInstalled: Bool {
        let info = KextManagerCopyLoadedKextInfo(nil, nil)?.takeUnretainedValue() as? [String: AnyObject]
        return info?["com.silabs.driver.CP210xVCPDriver"] != nil
    }

}
