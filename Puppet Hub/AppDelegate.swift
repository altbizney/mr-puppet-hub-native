//
//  AppDelegate.swift
//  Puppet Master
//
//  Created by Edward Wellbrook on 25/07/2019.
//  Copyright © 2019 Thinko LLC. All rights reserved.
//

import Cocoa
import SwiftSerial

func dispatchMainSync(_ block: () -> Void) {
    if Thread.current.isMainThread {
        return block()
    }

    DispatchQueue.main.sync(execute: block)
}

enum LogType: String {
    case info = "INFO"
    case echo = "ECHO"
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var textView: NSTextView!

    var serialPort: Serial?


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        self.reloadToolbar()

        let serialPortPath = ProcessInfo.processInfo.environment["SERIAL_PORT"] ?? "/dev/cu.SLAB_USBtoUART"
        self.connectToPort(path: serialPortPath)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


    private func connectToPort(path: String) {
        self.serialPort = Serial(path: path)
        self.serialPort?.delegate = self

        self.appendLog("Connecting...", type: .info)

        DispatchQueue.global(qos: .userInitiated).async {
            self.serialPort?.run()
        }
    }

    private func appendLog(_ string: String, type: LogType) {
        self.textView?.string += "\(Date()) [\(type.rawValue)] \(string)\n"
    }

    private func reloadToolbar() {
        let toolbar = NSToolbar(identifier: "toolbar")
        toolbar.delegate = self

        self.window.toolbar = nil
        self.window.toolbar = toolbar
    }

    @objc func handleReconnectButton(_ sender: Any) {
        let serialPortPath = ProcessInfo.processInfo.environment["SERIAL_PORT"] ?? "/dev/cu.SLAB_USBtoUART"
        self.connectToPort(path: serialPortPath)
    }

}

extension AppDelegate: NSToolbarDelegate {

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            NSToolbarItem.Identifier.flexibleSpace,
            NSToolbarItem.Identifier("reconnect"),
        ]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return self.toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return self.toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier.rawValue {
        case "reconnect":
            let button = NSButton(image: NSImage(named: "NSRefreshTemplate")!, target: self, action: #selector(self.handleReconnectButton(_:)))
            button.toolTip = "Reconnect"
            button.bezelStyle = .texturedRounded
            button.isEnabled = (self.serialPort?.isConnected == false)

            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.view = button

            return item

        default:
            return NSToolbarItem(itemIdentifier: itemIdentifier)
        }
    }

}

extension AppDelegate: SerialDelegate {

    func serialDidConnect(_ serial: Serial) {
        dispatchMainSync {
            self.reloadToolbar()
            self.appendLog("Connected to \(serial.name)", type: .info)
        }
    }

    func serialDidDisconnect(_ serial: Serial) {
        dispatchMainSync {
            self.reloadToolbar()
            self.appendLog("Disconnected...", type: .info)
        }
    }

    func serial(_ serial: Serial, didFailConnectWithError error: Error) {
        dispatchMainSync {
            self.reloadToolbar()
            self.appendLog("Connection failed: \(error.localizedDescription)", type: .info)
            self.appendLog("Check Mr. Puppet is correctly plugged in and click the Reconnect button\n", type: .info)
        }
    }

    func serialDidTimeOut(_ serial: Serial) {
        dispatchMainSync {
            self.reloadToolbar()
            self.appendLog("Connection timed out", type: .info)
        }
    }

    func serial(_ serial: Serial, didReadLine string: String) {
        dispatchMainSync {
            self.appendLog(string, type: .echo)
        }
    }

}
