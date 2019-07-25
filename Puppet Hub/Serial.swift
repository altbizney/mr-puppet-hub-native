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
    func serial(_ serial: Serial, didReadLine string: String)
}

final class Serial {

    private let port: SerialPort

    weak var delegate: SerialDelegate?


    init(path: String) {
        self.port = SerialPort(path: "/dev/ttys002")
    }

    func run() {
        do {
            try self.port.open(receive: true, transmit: false)
            self.delegate?.serialDidConnect(self)
        } catch {
            fatalError(error.localizedDescription)
        }

        defer {
            self.port.close()
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
