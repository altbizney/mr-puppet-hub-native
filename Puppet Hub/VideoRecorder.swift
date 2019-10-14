//
//  VideoRecorder.swift
//  Mr. Puppet Hub
//
//  Created by Edward Wellbrook on 14/10/2019.
//  Copyright © 2019 Thinko LLC. All rights reserved.
//

import Foundation
import AVFoundation

class VideoRecorder: NSObject {

    let captureSession = AVCaptureSession()
    let movieFileOutput = AVCaptureMovieFileOutput()

    var completion: ((Result<URL, Error>) -> Void)?


    override init() {
        super.init()
    }

    func start() {
        self.captureSession.sessionPreset = .low
        self.captureSession.beginConfiguration()

        guard let videoDevice = AVCaptureDevice.default(for: .video) else {
            return
        }

        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            return
        }

        guard self.captureSession.canAddInput(videoDeviceInput) else {
            return
        }

        self.captureSession.addInput(videoDeviceInput)


        let movieFileOutput = AVCaptureMovieFileOutput()

        guard self.captureSession.canAddOutput(movieFileOutput) else {
            return
        }

        self.captureSession.addOutput(movieFileOutput)

        self.captureSession.commitConfiguration()

        self.captureSession.startRunning()

        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4", isDirectory: false)
        movieFileOutput.startRecording(to: fileURL, recordingDelegate: self)
    }

    func stop(completion: @escaping (Result<URL, Error>) -> Void) {
        self.completion = completion

        self.movieFileOutput.stopRecording()
        self.captureSession.stopRunning()
    }

}

extension VideoRecorder: AVCaptureFileOutputRecordingDelegate {

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let err = error, ((err as NSError).userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool) != true {
            self.completion?(.failure(err))
        } else {
            self.completion?(.success(outputFileURL))
        }
    }

}
