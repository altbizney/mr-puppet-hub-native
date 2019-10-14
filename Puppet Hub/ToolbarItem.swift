//
//  ToolbarItem.swift
//  Mr. Puppet Hub
//
//  Created by Edward Wellbrook on 15/10/2019.
//  Copyright © 2019 Thinko LLC. All rights reserved.
//

import Foundation
import Cocoa

class ToolbarItem: NSToolbarItem {

    var isActive = true {
        didSet {
            self.isEnabled = self.isActive
            (self.view as? NSControl)?.isEnabled = self.isActive
        }
    }


    override func validate() {
        self.isEnabled = self.isActive
        (self.view as? NSControl)?.isEnabled = self.isActive
    }

}
