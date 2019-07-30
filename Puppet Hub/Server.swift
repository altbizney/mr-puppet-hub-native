//
//  Server.swift
//  Mr. Puppet Hub
//
//  Created by Edward Wellbrook on 29/07/2019.
//  Copyright © 2019 Thinko LLC. All rights reserved.
//

import Foundation

struct WebSocketServer {

    private init() {}


    static func start(port: Int32) {
        var contextInfo = lws_context_creation_info()
        contextInfo.port = port
        contextInfo.protocols = UnsafePointer(&WebSocketServer.libwebsocket_protocols)

        let context = lws_create_context(&contextInfo)

        while true {
            lws_service(context, 50)
        }
    }


    static func broadcast(message: String) {
        var msg = message.utf8CString.compactMap({ return UInt8($0) })

        for conn in WebSocketServer.wsiConnections {
            lws_write(conn, UnsafeMutablePointer(&msg), msg.count, LWS_WRITE_TEXT)
        }
    }


    // MARK - Internals

    private static var wsiConnections: Set<OpaquePointer> = []

    private static var libwebsocket_protocols: [lws_protocols] = [
        lws_protocols(name: "outbound", callback: { (wsi, reason, user, in, len) -> Int32 in
            return WebSocketServer.http_handler(wsi: wsi, reason: reason, user: user, in: `in`, len: len)
        }, per_session_data_size: 0, rx_buffer_size: 0, id: 0, user: nil, tx_packet_size: 0),

        lws_protocols(name: nil, callback: nil, per_session_data_size: 0, rx_buffer_size: 0, id: 0, user: nil, tx_packet_size: 0)
    ]

    private static func http_handler(wsi: OpaquePointer?, reason: lws_callback_reasons, user: UnsafeMutableRawPointer?, in: UnsafeMutableRawPointer?, len: Int) -> Int32 {
        switch reason {
        case LWS_CALLBACK_ESTABLISHED:
            if let wsi = wsi {
                WebSocketServer.wsiConnections.insert(wsi)
            }

        case LWS_CALLBACK_CLOSED:
            if let wsi = wsi {
                WebSocketServer.wsiConnections.remove(wsi)
            }

        default:
            break
        }

        return 0
    }

}
