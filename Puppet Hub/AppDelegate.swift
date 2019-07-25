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

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var textView: NSTextView!

    var serialPort: Serial?


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let serialPortPath = ProcessInfo.processInfo.environment["SERIAL_PORT"]

        self.serialPort = Serial(path: serialPortPath ?? "/dev/cu.SLAB_USBtoUART")
        self.serialPort?.delegate = self


        self.textView.string = "[\(Date())] [INFO] Connecting...\n"

        DispatchQueue.global(qos: .userInitiated).async {
            self.serialPort?.run()
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

}

extension AppDelegate: SerialDelegate {

    func serialDidConnect(_ serial: Serial) {
        dispatchMainSync {
            self.textView?.string += "[\(Date())] [INFO] Connected...\n"
        }
    }

    func serial(_ serial: Serial, didReadLine string: String) {
        dispatchMainSync {
            self.textView?.string += "[\(Date())] [ECHO] \(string)\n"
        }
    }

}
