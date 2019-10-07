//
//  Controller.swift
//  Mr. Puppet Hub
//
//  Created by Edward Wellbrook on 04/10/2019.
//  Copyright © 2019 Thinko LLC. All rights reserved.
//

import Foundation

protocol ControllerDelegate: class {
    func controller(_ controller: Controller, didConnectToSourceWithIdentifier identifier: String)
    func controller(_ controller: Controller, didFailToConnectToSourceWithError error: Error)
    func controllerDidDisconnectSource(_ controller: Controller)
    func controller(_ controller: Controller, didBroadcastMessage message: String)
}

class Controller {

    var serialPort: Serial?

    var fileTimer: Timer?

    var isConnected: Bool {
        return self.serialPort?.isConnected == true || self.fileTimer != nil
    }

    weak var delegate: ControllerDelegate?
    weak var serialDelegate: SerialDelegate?


    func startWebServer(port: Int32) {
        DispatchQueue.global(qos: .background).async {
            WebSocketServer.start(port: port)
        }
    }

    func connectToPort(path: String) {
        self.serialPort = Serial(path: path)
        self.serialPort?.delegate = self

        DispatchQueue.global(qos: .userInitiated).async {
            self.serialPort?.run()
        }
    }

    func readFile(at url: URL) {
        guard let data = FileManager.default.contents(atPath: url.path) else {
            let error = NSError(domain: "com.thinko.Puppet-Hub.controller", code: -43537, userInfo: [NSLocalizedDescriptionKey: "Unable to read contents of file"])
            self.delegate?.controller(self, didFailToConnectToSourceWithError: error)
            return
        }

        guard let str = String(data: data, encoding: .utf8) else {
            let error = NSError(domain: "com.thinko.Puppet-Hub.controller", code: -43537, userInfo: [NSLocalizedDescriptionKey: "File is in incorrect format and can't be read"])
            self.delegate?.controller(self, didFailToConnectToSourceWithError: error)
            return
        }

        DispatchQueue.global(qos: .userInteractive).async {
            let lines = str.split(whereSeparator: { (char) -> Bool in
                return char.isNewline
            })

            var idx = lines.startIndex

            let timer = Timer.scheduledTimer(withTimeInterval: 60 / 1000, repeats: true) { [weak self] (timer) in
                print(Date())

                if idx == lines.endIndex {
                    idx = lines.startIndex
                    self?.broadcast(message: "DEBUG;LOOP")
                }

                self?.broadcast(message: String(lines[idx]))

                idx = lines.index(after: idx)
            }

            self.fileTimer = timer

            DispatchQueue.main.async {
                self.delegate?.controller(self, didConnectToSourceWithIdentifier: url.lastPathComponent)
            }

            let runLoop = RunLoop.current
            runLoop.add(timer, forMode: .default)
            runLoop.run()
        }
    }

    func disconnect() {
        if let port = self.serialPort {
            port.close()
            self.serialPort = nil
        }

        if let timer = self.fileTimer {
            timer.invalidate()
            self.fileTimer = nil

            self.delegate?.controllerDidDisconnectSource(self)
        }
    }

    func broadcast(message: String) {
        WebSocketServer.broadcast(message: message)

        self.delegate?.controller(self, didBroadcastMessage: message)
    }

}

extension Controller: SerialDelegate {

    func serialDidConnect(_ serial: Serial) {
        self.delegate?.controller(self, didConnectToSourceWithIdentifier: serial.name)
    }

    func serialDidDisconnect(_ serial: Serial) {
        self.delegate?.controllerDidDisconnectSource(self)
    }

    func serialDidTimeOut(_ serial: Serial) {
        self.serialDelegate?.serialDidTimeOut(serial)
    }

    func serial(_ serial: Serial, didFailConnectWithError error: Error) {
        self.serialDelegate?.serial(serial, didFailConnectWithError: error)
    }

    func serial(_ serial: Serial, didReadLine string: String) {
        self.broadcast(message: string)
        self.serialDelegate?.serial(serial, didReadLine: string)
    }

}
