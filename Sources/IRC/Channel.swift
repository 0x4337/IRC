//
//  Channel.swift
//  Bits
//
//  Created by Feets on 27/01/20.
//

import Foundation

public class Channel {
        private unowned let server: Server
        public let name: String

        private var users = [User]()
        public var connectedUsers: [User] {
                return self.users
        }
        
        init(channelNamed name: String, server: Server) {
                self.server = server
                self.name = name
        }
        
        public func add(user: User) {
                self.users.append(user)
        }
        
        public func send(_ text: String) {
                self.server.connection?.send("PRIVMSG #\(name) :\(text)")
        }
}

extension Channel : Equatable {
        public static func == (lhs: Channel, rhs: Channel) -> Bool {
                return lhs.name == rhs.name
        }
}
