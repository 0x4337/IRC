//
//  IRCServerInputParser.swift
//  IRC
//
//  Created by Samuel Ryan Goodwin on 7/22/17.
//  Updated by Feets on 2020-01-07
//  Copyright © 2017 Roundwall Software, Feets. All rights reserved.
//

import Foundation
#if os(Linux)
import FoundationNetworking
#endif

extension IRCConnection {
        func processLine(_ message: String) {
                print("RECEIVED \(message)")
                
                if message.hasPrefix("PING") {
                        self.send("PONG")
                        return
                }
                
                var tags: [String : String]?
                let components = message.split(separator: " ")
                if let firstComponent = components.first, firstComponent.hasPrefix("@") {
                        tags = IRCConnection.parseTags(String(firstComponent))
                }
                let processedMessage = tags != nil ? components.dropFirst().joined(separator: " ") : message
                
                if processedMessage.hasPrefix(":") {
                        let firstSpaceIndex = processedMessage.firstIndex(of: " ")!
                        let source = processedMessage[..<firstSpaceIndex]
                        let rest = processedMessage[firstSpaceIndex...].trimmingCharacters(in: .whitespacesAndNewlines)
                        print(source)
                        
                        if rest.hasPrefix("PRIVMSG") {
                                let remaining = rest[rest.index(processedMessage.startIndex, offsetBy: 8)...]
                                
                                if remaining.hasPrefix("#") {
                                        let split = remaining.components(separatedBy: ":")
                                        let channelName = split[0].trimmingCharacters(in: CharacterSet(charactersIn: " #"))
                                        let nick = source.components(separatedBy: "!")[0].trimmingCharacters(in: CharacterSet(charactersIn: ":"))
                                        let message = split[1]
                                        
                                        if let channel = self.server.connectedChannels[channelName] {
                                                let user = channel.connectedUsers.first(where: { $0.nick == nick }) ?? User(username: nick, nick: nick)
                                                self.delegate?.ircConnection(self, didReceiveChannelMessage: message, withTags: tags, fromUser: user, inChannel: channel)
                                        }
                                }
                        } else if rest.hasPrefix("JOIN") {
                                let nick = source.components(separatedBy: "!")[0].trimmingCharacters(in: CharacterSet(charactersIn: ":"))
                                let channelName = rest[rest.index(processedMessage.startIndex, offsetBy: 5)...].trimmingCharacters(in: CharacterSet(charactersIn: "# "))
                                
                                if let channel = self.server.connectedChannels[channelName] {
                                        let user = User(username: nick, nick: nick)
                                        if !channel.connectedUsers.contains(where: { $0 == user }) { channel.add(user: user) }
                                        self.delegate?.ircConnection(self, userDidJoinChannel: channel, user: user)
                                }
                        } else {
                                let server = source.trimmingCharacters(in: CharacterSet(charactersIn: ": "))
                                
                                // :development.irc.roundwallsoftware.com 353 mukman = #clearlyafakechannel :mukman @sgoodwin\r\n:development.irc.roundwallsoftware.com 366 mukman #clearlyafakechannel :End of /NAMES list.
                                
                                if rest.hasSuffix(":End of /NAMES list.") {
                                        let scanner = Scanner(string: rest)
                                        scanner.scanUpTo("#", into: nil)
                                        
                                        var channel: NSString?
                                        
                                        scanner.scanUpTo(" ", into: &channel)
                                        
                                        let channelName = (channel as String?)!.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
                                        
                                        var users = [String]()
                                        var user: NSString?
                                        scanner.scanUpTo(" ", into: &user)
                                        users.append((user as String?)!.trimmingCharacters(in: CharacterSet(charactersIn: ":")))
                                        
                                        if var channel = self.server.connectedChannels[channelName] {
                                                users.forEach { user in
                                                        if channel.connectedUsers.first(where: { $0.nick == user }) == nil {
                                                                let user = User(username: user, nick: user)
                                                                channel.add(user: user)
                                                        }
                                                }
                                        }
                                }
                                
                                if rest.contains(":") {
                                        let serverMessage = rest.components(separatedBy: ":")[1]
                                        self.delegate?.ircConnection(self, didReceiveServerMessage: serverMessage)
                                } else {
                                        self.delegate?.ircConnection(self, didReceiveServerMessage: rest)
                                }
                        }
                }
        }
        
        static private func parseTags(_ string: String) -> [String : String] {
                let components = string.split(separator: ";")
                return components.reduce(into: [String : String]()) { result, component in
                        let split = component.split(separator: "=")
                        if split.count == 2 {
                                result[String(split[0])] = String(split[1])
                        }
                }
        }
}

enum IRCServerInput: Equatable {
        case unknown(raw: String)
        case ping
        case serverMessage(server: Server, message: String)
        case channelMessage(channel: Channel, user: User, message: String, tags: [String : String]?)
        case joinMessage(userNick: String, channel: Channel)
        case userList(channel: String, users: [User])
}

func ==(lhs: IRCServerInput, rhs: IRCServerInput) -> Bool{
        switch (lhs, rhs) {
        case (.ping, .ping):
                return true
        case (.channelMessage(let lhsChannel, let lhsUser, let lhsMessage, let lhsTags),
              .channelMessage(let rhsChannel, let rhsUser, let rhsMessage, let rhsTags)):
                return lhsChannel == rhsChannel && lhsMessage == rhsMessage && lhsUser == rhsUser && lhsTags == rhsTags
        case (.serverMessage(let lhsServer, let lhsMessage),
              .serverMessage(let rhsServer, let rhsMessage)):
                return lhsServer == rhsServer && lhsMessage == rhsMessage
        case (.joinMessage(let lhsUser, let lhsChannel), .joinMessage(let rhsUser, let rhsChannel)):
                return lhsUser == rhsUser && lhsChannel == rhsChannel
        case (.userList(let lhsChannel, let lhsUsers), .userList(let rhsChannel, let rhsUsers)):
                return lhsChannel == rhsChannel && lhsUsers == rhsUsers
        default:
                return false
        }
}
