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

    var fileName: String?
    var fileTimer: RepeatingTimer?

    var recordingFileHandle: (URL, FileHandle)?

    var videoRecorder: VideoRecorder?

    var isConnected: Bool {
        return self.serialPort?.isConnected == true || self.fileTimer != nil
    }

    var sourceName: String? {
        if let portName = self.serialPort?.name {
            return portName
        }

        if let fileName = self.fileName {
            return fileName
        }

        return nil
    }

    var isRecording: Bool {
        return self.recordingFileHandle != nil
    }


    weak var delegate: ControllerDelegate?
    weak var serialDelegate: SerialDelegate?


    func startWebServer(port: Int32) {
        DispatchQueue.global(qos: .background).async {
            WebSocketServer.onMessageHandler = { message in
                if let string = String(data: message, encoding: .utf8) {
                    WebSocketServer.broadcast(message: string)
                }
            }
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

            let timer = RepeatingTimer(timeInterval: 60 / 1000)
            timer.eventHandler = { [weak self] in
                if idx == lines.endIndex {
                    idx = lines.startIndex
                    self?.broadcast(message: "DEBUG;LOOP")
                }

                self?.broadcast(message: String(lines[idx]))

                idx = lines.index(after: idx)
            }

//            let timer = Timer.scheduledTimer(withTimeInterval: 60 / 1000, repeats: true) { [weak self] (timer) in
//
//            }

            self.fileTimer = timer

            DispatchQueue.main.async {
                self.fileName = url.lastPathComponent
                self.delegate?.controller(self, didConnectToSourceWithIdentifier: url.lastPathComponent)
            }

            timer.resume()
//            let runLoop = RunLoop.current
//            runLoop.add(timer, forMode: .)
//            runLoop.run()
        }
    }

    func disconnect() {
        if let port = self.serialPort {
            port.close()
            self.serialPort = nil
        }

        if let timer = self.fileTimer {
            timer.suspend()
            self.fileTimer = nil
            self.fileName = nil

            self.delegate?.controllerDidDisconnectSource(self)
        }

        return
    }

    func broadcast(message: String) {
        print(message)

        WebSocketServer.broadcast(message: message)

        if let (_, fileHandle) = self.recordingFileHandle, let data = message.appending("\n").data(using: .utf8) {
            fileHandle.write(data)
        }

        self.delegate?.controller(self, didBroadcastMessage: message)
    }

    func startRecordingMessages() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil)

        let handle = try! FileHandle(forWritingTo: url)
        handle.seekToEndOfFile()

        self.recordingFileHandle = (url, handle)
    }

    func stopRecordingMessages() -> URL? {
        guard let (url, handle) = self.recordingFileHandle else {
            return nil
        }

        self.recordingFileHandle = nil

        handle.closeFile()

        return url
    }

    func startRecordingVideo() {
        self.videoRecorder = VideoRecorder()
        self.videoRecorder?.start()
    }

    func stopRecordingVideo(completion: @escaping (Result<URL?, Error>) -> Void) {
        guard let recorder = self.videoRecorder else {
            return completion(.success(nil))
        }

        recorder.stop(completion: { result in
            switch result {
            case .success(let url):
                completion(.success(url))
            case .failure(let err):
                completion(.failure(err))
            }
        })
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
