//
//  DeviceMenuDelegate.swift
//  Mr. Puppet Hub
//
//  Created by Edward Wellbrook on 04/10/2019.
//  Copyright © 2019 Thinko LLC. All rights reserved.
//

import AppKit

class DeviceMenuDelegate: NSObject {

    var devices: [String] {
        return availableSerialDevices().map({ $1 })
    }


    func configureMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(withTitle: menu.title, action: nil, keyEquivalent: "")

        if self.devices.isEmpty == false {
            for device in self.devices {
                menu.addItem(withTitle: device, action: nil, keyEquivalent: "")
            }

            menu.addItem(.separator())
        }

        let menuItem = NSMenuItem(title: "Open file...", action: nil, keyEquivalent: "")
        menuItem.identifier = NSUserInterfaceItemIdentifier("com.thinko.Puppet-Hub.source.file")
        menu.addItem(menuItem)

        menu.delegate = self
    }

}

extension DeviceMenuDelegate: NSMenuDelegate {

    func menuNeedsUpdate(_ menu: NSMenu) {
        self.configureMenu(menu)
    }

}
