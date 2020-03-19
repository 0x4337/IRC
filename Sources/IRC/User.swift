//
//  User.swift
//  Bits
//
//  Created by Feets on 27/01/20.
//

import Foundation
#if os(Linux)
import FoundationNetworking
#endif

public class User {
        public let username: String
        public let nick: String
        public let permission: String?
        
        public init(username: String, nick: String, permission: String? = nil) {
                self.username = username
                self.nick = nick
                self.permission = permission
        }
}

extension User : Equatable {
        public static func == (lhs: User, rhs: User) -> Bool {
                return lhs.username == rhs.username && lhs.nick == rhs.nick
        }
}
