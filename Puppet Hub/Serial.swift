//
//  Serial.swift
//  Puppet Master
//
//  Created by Edward Wellbrook on 25/07/2019.
//  Copyright © 2019 Thinko LLC. All rights reserved.
//

import Foundation
import SwiftSerial

protocol SerialDelegate: class {
    func serialDidConnect(_ serial: Serial)
    func serialDidDisconnect(_ serial: Serial)
    func serialDidTimeOut(_ serial: Serial)
    func serial(_ serial: Serial, didFailConnectWithError error: Error)
    func serial(_ serial: Serial, didReadLine string: String)
}

final class Serial {

    private let port: SerialPort

    let name: String

    var isConnected: Bool = false

    weak var delegate: SerialDelegate?


    init(path: String) {
        self.name = path
        self.port = SerialPort(path: path)
    }

    func run() {
        do {
            try self.port.open(receive: true, transmit: false)
            self.isConnected = true
            self.delegate?.serialDidConnect(self)
        } catch {
            self.delegate?.serial(self, didFailConnectWithError: error)
            return
        }

        defer {
            self.isConnected = false
            self.port.close()
            self.delegate?.serialDidDisconnect(self)
        }

        self.port.setSettings(
            receiveRate: BaudRate(rawValue: 250000),
            transmitRate: BaudRate(rawValue: 250000),
            minimumBytesToRead: 1,
            timeout: 0
        )

        while let line = try? self.port.readLine() {
            self.delegate?.serial(self, didReadLine: line)
        }
    }

}
