//
//  ConnectionUser.swift
//  IRC
//
//  Created by Feets on 28/01/20.
//

import Foundation

public struct ConnectionUser {
        public let username: String
        public let nick: String
        public let pass: String?
        
        public init(username: String, nick: String, pass: String? = nil) {
                self.username = username
                self.nick = nick
                self.pass = pass
        }
}

extension ConnectionUser : Equatable {
        public static func == (lhs: ConnectionUser, rhs: ConnectionUser) -> Bool {
                return lhs.username == rhs.username && lhs.nick == rhs.nick
        }
}
