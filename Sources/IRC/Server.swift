//
//  Server.swift
//  IRC
//
//  Created by Feets on 28/01/20.
//

import Foundation

public class Server {
        public weak var connection: IRCConnection?
        
        public let name: String
        public let hostname: String
        public let port: Int
        
        private var channels = [Channel]()
        public var connectedChannels: [Channel] {
                return self.channels
        }
        
        public init(name: String, hostname: String, port: Int) {
                self.name = name
                self.hostname = hostname
                self.port = port
        }
        
        public func join(_ channelName: String) {
                self.connection?.send("JOIN #\(channelName)")
                let channel = Channel(channelNamed: channelName, server: self)
                self.channels.append(channel)
        }
}

extension Server : Equatable {
        public static func == (lhs: Server, rhs: Server) -> Bool {
                return lhs.name == rhs.name && lhs.connection == rhs.connection
        }
}
