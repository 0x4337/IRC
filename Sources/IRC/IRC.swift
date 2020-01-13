//
//  IRC.swift
//  IRC
//
//  Created by Samuel Ryan Goodwin on 8/12/17.
//  Updated by Feets on 2020-01-07
//  Copyright © 2017, 2020 Roundwall Software, Feets. All rights reserved.
//

import Foundation

public struct IRCUser {
        public let username: String
        public let realName: String
        public let nick: String
        
        public init(username: String, realName: String, nick: String) {
                self.username = username
                self.realName = realName
                self.nick = nick
        }
}

public class IRCChannel {
        public var delegate: IRCChannelDelegate? = nil {
                didSet {
                        guard let delegate = delegate else {
                                return
                        }
                        
                        buffer.forEach { (line) in
                                delegate.didReceiveMessage(self, message: line)
                        }
                        buffer = []
                }
        }
        public let name: String
        public let server: IRCServer
        private var buffer = [String]()
        
        public init(name: String, server: IRCServer) {
                self.name = name
                self.server = server
        }
        
        
        func receive(_ text: String) {
                if let delegate = self.delegate {
                        delegate.didReceiveMessage(self, message: text)
                } else {
                        buffer.append(text)
                }
        }
        
        public func send(_ text: String) {
                server.send("PRIVMSG #\(name) :\(text)")
        }
}

public class IRCServer {
        public var delegate: IRCServerDelegate? {
                didSet {
                        guard let delegate = delegate else {
                                return
                        }
                        
                        buffer.forEach { (line) in
                                delegate.didReceiveMessage(self, message: line)
                        }
                        buffer = []
                }
        }
        
        private var buffer = [String]()
        private var session: URLSession
        private var task: URLSessionStreamTask!
        private var channels = [IRCChannel]()
        
        public required init(session: URLSession = URLSession.shared) {
                self.session = session
        }
        
        public func connect(hostname: String, port: Int, user: IRCUser, userPass: String?) {
                task = session.streamTask(withHostName: hostname, port: port)
                task.resume()
                read()
                
                if let userPass = userPass { send("PASS \(userPass)") }
                send("USER \(user.username) 0 * :\(user.realName)")
                send("NICK \(user.nick)")
        }
        
        public func disconnect() {
                self.task.closeRead()
                self.task.closeWrite()
                self.task.cancel()
        }
        
        private func read() {
                task.readData(ofMinLength: 0, maxLength: 9999, timeout: 0) { (data, atEOF, error) in
                        guard error == nil else {
                                print(error!)
                                self.disconnect()
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
        
        private func processLine(_ message: String) {
                let input = IRCServerInputParser.parseServerMessage(message)
                switch input {
                case .serverMessage(_, let message):
                        print(message)
                        if let delegate = self.delegate {
                                delegate.didReceiveMessage(self, message: message)
                        } else {
                                self.buffer.append(message)
                        }
                case .joinMessage(let user, let channelName):
                        self.channels.forEach({ (channel) in
                                if channel.name == channelName {
                                        channel.receive("\(user) joined \(channelName)")
                                }
                        })
                case .channelMessage(let channelName, let user, let message):
                        self.channels.forEach({ (channel) in
                                if channel.name == channelName {
                                        channel.receive("\(user): \(message)")
                                }
                        })
                case .userList(let channelName, let users):
                        self.channels.forEach({ (channel) in
                                if channel.name == channelName {
                                        users.forEach({ (user) in
                                                channel.receive("\(user) joined")
                                        })
                                }
                        })
                default:
                        print("Unknown: \(message)")
                }
        }
        
        public func send(_ message: String) {
                task.write((message + "\r\n").data(using: .utf8)!, timeout: 0) { (error) in
                        if let error = error {
                                print("Failed to send: \(String(describing: error))")
                        } else {
                                print("Sent!")
                        }
                }
        }
        
        public func join(_ channelName: String) -> IRCChannel {
                send("JOIN #\(channelName)")
                let channel = IRCChannel(name: channelName, server: self)
                channels.append(channel)
                return channel
        }
}

public protocol IRCServerDelegate {
        func didReceiveMessage(_ server: IRCServer, message: String)
}


public protocol IRCChannelDelegate {
        func didReceiveMessage(_ channel: IRCChannel, message: String)
}
