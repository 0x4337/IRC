//
//  IRC.swift
//  IRC
//
//  Created by Samuel Ryan Goodwin on 8/12/17.
//  Updated by Feets on 2020-01-07
//  Copyright © 2017, 2020 Roundwall Software, Feets. All rights reserved.
//

import Foundation

public class IRCConnection {
        public weak var delegate: IRCConnectionDelegate?
        
        public let server: Server
        public let user: ConnectionUser
        private var capabilities: [String]? = nil
        
        private var session: URLSession
        private var task: URLSessionStreamTask!
        
        public var isConnected: Bool { return self.task.state == .running }
        
        public init(server: Server, user: ConnectionUser, session: URLSession) {
                self.server = server
                self.user = user
                self.session = session
        }
        
        public func connect(joiningChannels channels: [String], requestingCapabilities capabilities: [String]?) {
                self.capabilities = (capabilities != nil ? capabilities : self.capabilities)
                
                self.server.connection = self
                self.task = session.streamTask(withHostName: self.server.hostname, port: self.server.port)
                self.task.resume()
                self.read()
                
                if let userPass = self.user.pass { self.send("PASS \(userPass)") }
                send("USER \(self.user.username) 0 * :\(self.user.username)")
                send("NICK \(self.user.nick)")
                
                if let capabilities = self.capabilities {
                        for capability in capabilities {
                                send("CAP REQ \(capability)")
                        }
                }
                
                for channel in channels { self.server.join(channel) }
        }
        
        private func read() {
                task.readData(ofMinLength: 0, maxLength: 9999, timeout: 0) { (data, atEOF, error) in
                        guard error == nil else {
                                print("Error: \(error!)")
                                self.task.closeRead()
                                self.task.closeWrite()
                                self.task.cancel()
                                self.connect(joiningChannels: self.server.connectedChannels.map { $0.name }, requestingCapabilities: nil)
                                return
                        }
                        
                        guard let data = data, let message = String(data: data, encoding: .utf8) else {
                                return
                        }
                        
                        for line in message.split(separator: "\r\n") {
                                self.processLine(String(line))
                        }
                        
                        self.read()
                }
        }
        
        public func send(_ message: String) {
                task.write((message + "\r\n").data(using: .utf8)!, timeout: 0) { (error) in
                        if let error = error {
                                print("Failed to send: \(String(describing: error))")
                        } else {
                                print("-> \(message)")
                        }
                }
        }
        
        func receive(user: String?, message: String) {
                self.delegate?.ircConnection(self, didReceiveServerMessage: message)
        }
}

extension IRCConnection : Equatable {
        public static func == (lhs: IRCConnection, rhs: IRCConnection) -> Bool {
                return lhs.user == rhs.user && lhs.isConnected == rhs.isConnected
        }
}

public protocol IRCConnectionDelegate : class {
        // Server messages
        func ircConnection(_ connection: IRCConnection, didReceiveServerMessage message: String)
        
        // Channel messages
        func ircConnection(_ connection: IRCConnection, didReceiveChannelMessage message: String, withTags tags: [String : String]?, fromUser user: User, inChannel channel: Channel)
        func ircConnection(_ connection: IRCConnection, userDidJoinChannel: Channel, user: User)
}
