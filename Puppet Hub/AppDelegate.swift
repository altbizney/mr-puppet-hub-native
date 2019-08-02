//
//  AppDelegate.swift
//  Puppet Master
//
//  Created by Edward Wellbrook on 25/07/2019.
//  Copyright © 2019 Thinko LLC. All rights reserved.
//

import Cocoa
import SwiftSerial
import IOKit
import IOKit.serial
import IOKit.kext

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

    var devices: [String] = []
    var serialPort: Serial?

    lazy var logs = [self.textView.string]
    lazy var throttler = Throttler(minimumDelay: 0.05, queue: .main)


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if #available(OSX 10.14, *) {
            NSApp.appearance = NSAppearance(named: .darkAqua)
        } else {
            self.window.titlebarAppearsTransparent = true
            self.window.backgroundColor = #colorLiteral(red: 0.1298420429, green: 0.1298461258, blue: 0.1298439503, alpha: 1)
        }

        self.reloadToolbar()

        DispatchQueue.global(qos: .background).async {
            WebSocketServer.start(port: 3000)
        }

        let devices = availableSerialDevices()
        self.devices = devices.map({ $1 })

        print(devices)

        self.reloadToolbar()

        if let info = KextManagerCopyLoadedKextInfo(nil, nil)?.takeUnretainedValue() as? [String: AnyObject], info["com.silabs.driver.CP210xVCPDriver"] == nil {
            let error = NSError(domain: "com.thinko.Puppet-Hub", code: -222, userInfo: [NSLocalizedDescriptionKey: "Missing USB driver"])
            let alert = NSAlert(error: error)
            alert.messageText = "Missing USB driver"
            alert.informativeText = """
            Download and install the USB Driver for macOS.
            """

            alert.addButton(withTitle: "Download Driver")
            alert.addButton(withTitle: "Cancel")

            let result = alert.runModal()

            if result == .alertFirstButtonReturn {
                let url = URL(string: "https://www.silabs.com/products/development-tools/software/usb-to-uart-bridge-vcp-drivers")!
//                let url = URL(string: "https://www.silabs.com/documents/public/software/Mac_OSX_VCP_Driver.zip")!
                NSWorkspace.shared.open(url)
            }

            exit(EXIT_FAILURE)

        } else if self.devices.isEmpty {
            let error = NSError(domain: "com.thinko.Puppet-Hub", code: -222, userInfo: [NSLocalizedDescriptionKey: "No compatiable devices found"])
            let alert = NSAlert(error: error)
            alert.messageText = "No compatiable devices found"
            alert.informativeText = """
            Mr. Puppet Hub couldn't find any USB devices to connect to. \
            Please check you have the USB drivers installed and Mr Puppet \
            is plugged in.
            """

            alert.runModal()
        }
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
        let logEntry = "\(Date()) [\(type.rawValue)] \(string)"
        self.logs.append(logEntry)

        let limit = 26

        if self.logs.count > limit {
            self.logs.removeFirst()
        }

        self.throttler.throttle { [weak self] in
            guard let self = self else {
                return
            }

            self.textView.string = self.logs.joined(separator: "\n")

            if self.textView.visibleRect.maxY - self.textView.bounds.maxY >= 0 {
                self.textView.scrollToEndOfDocument(nil)
            }
        }
    }

    private func reloadToolbar() {
        let toolbar = NSToolbar(identifier: "toolbar")
        toolbar.delegate = self

        self.window.toolbar = nil
        self.window.toolbar = toolbar
    }

    @objc func handleDeviceSelectButton(_ sender: Any) {
        guard let button = sender as? NSPopUpButton, let serialPortPath = button.selectedItem?.title else {
            return
        }

        self.connectToPort(path: serialPortPath)
    }

    @objc func handleReconnectButton(_ sender: Any) {
        guard let serialPortPath = self.serialPort?.name else {
            return
        }

        self.connectToPort(path: serialPortPath)
    }

}

extension AppDelegate: NSToolbarDelegate {

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            NSToolbarItem.Identifier("select-device"),
            NSToolbarItem.Identifier("reconnect"),
            NSToolbarItem.Identifier.flexibleSpace,
            NSToolbarItem.Identifier("server-info"),
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
        case "select-device":
            let button = NSPopUpButton(title: "", target: self, action: #selector(self.handleDeviceSelectButton(_:)))
            button.bezelStyle = .texturedRounded
            button.pullsDown = true
            button.addItem(withTitle: "Connect to Device")
            button.addItems(withTitles: self.devices)
            button.isEnabled = (self.devices.isEmpty == false && self.serialPort?.isConnected != true)
            button.sizeToFit()

            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.view = button

            return item

        case "reconnect":
            let button = NSButton(image: NSImage(named: "NSRefreshTemplate")!, target: self, action: #selector(self.handleReconnectButton(_:)))
            button.toolTip = "Reconnect"
            button.bezelStyle = .texturedRounded
            button.isEnabled = (self.serialPort?.isConnected == false)

            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.view = button

            return item

        case "server-info":
            let label = NSTextField(labelWithString: "Server listening on port 3000  ")
            label.font = NSFont.systemFont(ofSize: 13)
            label.textColor = NSColor.white.withAlphaComponent(0.6)

            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.view = label

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
            WebSocketServer.broadcast(message: string)
            self.appendLog(string, type: .echo)
        }
    }

}
