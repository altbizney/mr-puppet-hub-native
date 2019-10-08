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
import Sparkle

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

    lazy var controller = Controller()
    lazy var deviceMenuDelegate = DeviceMenuDelegate()

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

        self.controller.delegate = self
        self.controller.serialDelegate = self

        self.controller.startWebServer(port: 3000)

        self.reloadToolbar()

        SUUpdater.shared().feedURL = URL(string: "https://mr-puppet.herokuapp.com/hub-macos/appcast.xml")
        SUUpdater.shared().automaticallyChecksForUpdates = true
        SUUpdater.shared().checkForUpdatesInBackground()

        if DriverInfo.isDriverInstalled == false {
            self.presentMissingDriverError()
        } else if self.deviceMenuDelegate.devices.isEmpty {
            self.presentNoDevicesError()
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


    private func presentNoDevicesError() {
        let error = NSError(domain: "com.thinko.Puppet-Hub", code: -222, userInfo: [NSLocalizedDescriptionKey: "No compatiable devices found"])
        let alert = NSAlert(error: error)
        alert.messageText = "No compatiable devices found"
        alert.informativeText = """
        Mr. Puppet Hub couldn't find any USB devices to connect to. \
        Please check you have the USB drivers installed and Mr Puppet \
        is plugged in.
        """

        alert.beginSheetModal(for: self.window, completionHandler: nil)
    }

    private func presentMissingDriverError() {
        let error = NSError(domain: "com.thinko.Puppet-Hub", code: -222, userInfo: [NSLocalizedDescriptionKey: "Missing USB driver"])
        let alert = NSAlert(error: error)
        alert.messageText = "Missing USB driver"
        alert.informativeText = """
        Download and install the USB Driver for macOS.
        """

        alert.addButton(withTitle: "Download Driver")
        alert.addButton(withTitle: "Cancel")

        alert.beginSheetModal(for: self.window) { (result) in
            guard result == .alertFirstButtonReturn else {
                return
            }

            let url = URL(string: "https://www.silabs.com/products/development-tools/software/usb-to-uart-bridge-vcp-drivers")!
            NSWorkspace.shared.open(url)
            exit(EXIT_FAILURE)
        }
    }

    private func connectToPort(path: String) {
        self.appendLog("Connecting...", type: .info)
        self.controller.connectToPort(path: path)
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

    func openFile() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowsMultipleSelection = false

        openPanel.beginSheetModal(for: self.window) { (response) in
            guard response == .OK else {
                return
            }

            guard let fileURL = openPanel.urls.first else {
                return
            }

            self.controller.readFile(at: fileURL)
        }
    }

    func saveFile(tmpURL: URL) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYYY-MM-dd-HH-mm-SS"

        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = dateFormatter.string(from: Date()) + ".txt"

        savePanel.beginSheetModal(for: self.window) { (response) in
            guard response == .OK, let finalURL = savePanel.url else {
                return
            }

            try! FileManager.default.moveItem(at: tmpURL, to: finalURL)
        }
    }

    @objc func handleDeviceSelectButton(_ sender: Any) {
        guard let button = sender as? NSPopUpButton, let selectedItem = button.selectedItem else {
            return
        }

        if selectedItem.identifier?.rawValue == "com.thinko.Puppet-Hub.source.file" {
            self.openFile()

        } else {
            let serialPortPath = selectedItem.title
            self.controller.connectToPort(path: serialPortPath)
        }
    }

    @objc func handleDisconnectButton(_ sender: Any) {
        let recordingURL = self.controller.disconnect()
        self.reloadToolbar()

        if let url = recordingURL {
            self.saveFile(tmpURL: url)
        }
    }

    @objc func handleRecordButton(_ sender: Any) {
        if self.controller.isRecording {
            let recordingURL = self.controller.stopRecordingMessages()

            if let url = recordingURL {
                self.saveFile(tmpURL: url)
            }
        } else {
            self.controller.startRecordingMessages()
        }

        self.reloadToolbar()
    }

}

extension AppDelegate: NSToolbarDelegate {

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            NSToolbarItem.Identifier("select-device"),
            NSToolbarItem.Identifier("disconnect"),
            NSToolbarItem.Identifier("record"),
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
            let deviceMenu = NSMenu(title: "Select Source")
            self.deviceMenuDelegate.configureMenu(deviceMenu)

            let button = NSPopUpButton(title: "", target: self, action: #selector(self.handleDeviceSelectButton(_:)))
            button.bezelStyle = .texturedRounded
            button.pullsDown = true
            button.isEnabled = (self.controller.isConnected != true)
            button.sizeToFit()
            button.menu = deviceMenu

            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.view = button

            return item

        case "disconnect":
            let button = NSButton(title: "Disconnect", target: self, action: #selector(self.handleDisconnectButton(_:)))
            button.bezelStyle = .texturedRounded
            button.isEnabled = (self.controller.isConnected == true)

            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.view = button

            return item

        case "record":
            let button = NSButton(title: self.controller.isRecording ? "Stop Recording" : "Record", target: self, action: #selector(self.handleRecordButton(_:)))
            button.bezelStyle = .texturedRounded
            button.isEnabled = (self.controller.isConnected == true)

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

    }

    func serialDidDisconnect(_ serial: Serial) {

    }

    func serial(_ serial: Serial, didFailConnectWithError error: Error) {
        dispatchMainSync {
            self.reloadToolbar()
            self.appendLog("Connection failed: \(error.localizedDescription)", type: .info)
            self.appendLog("Check Mr. Puppet is correctly plugged in and select the source again\n", type: .info)
        }
    }

    func serialDidTimeOut(_ serial: Serial) {
        dispatchMainSync {
            self.reloadToolbar()
            self.appendLog("Connection timed out", type: .info)
        }
    }

    func serial(_ serial: Serial, didReadLine string: String) {

    }

}

extension AppDelegate: ControllerDelegate {

    func controller(_ controller: Controller, didConnectToSourceWithIdentifier identifier: String) {
        dispatchMainSync {
            self.reloadToolbar()
            self.appendLog("Connected to \(identifier)", type: .info)
        }
    }

    func controller(_ controller: Controller, didFailToConnectToSourceWithError error: Error) {
        dispatchMainSync {
            self.reloadToolbar()
            self.appendLog("Connection failed: \(error.localizedDescription)", type: .info)
        }
    }

    func controllerDidDisconnectSource(_ controller: Controller) {
        dispatchMainSync {
            self.reloadToolbar()
            self.appendLog("Disconnected...", type: .info)
        }
    }

    func controller(_ controller: Controller, didBroadcastMessage message: String) {
        dispatchMainSync {
            self.appendLog(message, type: .echo)
        }
    }

}
