//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Distributed Actors open source project
//
// Copyright (c) 2018-2019 Apple Inc. and the Swift Distributed Actors project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.md for the list of Swift Distributed Actors project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import DistributedActors
import DistributedActorsConcurrencyHelpers
import Foundation
import XCTest

internal enum ActorTestProbeCommand<M> {
    case watchCommand(who: AddressableActorRef, file: String, line: UInt)
    case unwatchCommand(who: AddressableActorRef)
    case stopCommand

    case realMessage(message: M)
}

extension ActorTestProbeCommand: NonTransportableActorMessage {}

/// A special actor that can be used in place of real actors, yet in addition exposes useful assertion methods
/// which make testing asynchronous actor interactions simpler.
///
/// - SeeAlso: `ActorableTestProbe` which is the equivalent API for `Actorable`s.
public class ActorTestProbe<Message: ActorMessage> {
    /// Name of the test probe (and underlying actor).
    public let name: String

    /// Naming strategy for anonymous test probes.
    /// By default test probes are named as `$testProbe-###`.
    public static var naming: ActorNaming {
        // has to be computed property since: static stored properties are not supported in generic types
        ActorNaming(unchecked: .prefixed(prefix: "$testProbe", suffixScheme: .sequentialNumeric))
    }

    typealias ProbeCommands = ActorTestProbeCommand<Message>
    internal let internalRef: ActorRef<ProbeCommands>
    internal let exposedRef: ActorRef<Message>

    /// The reference to the underlying "mock" actor.
    /// Sending messages to this reference allows the probe to inspect them using the `expect...` family of functions.
    public var ref: ActorRef<Message> {
        self.exposedRef
    }

    private let settings: ActorTestKitSettings
    private var expectationTimeout: TimeAmount {
        self.settings.expectationTimeout
    }

    /// Blocking linked queue, available to run assertions on
    private let messagesQueue = LinkedBlockingQueue<Message>()
    /// Blocking linked queue, available to run assertions on
    private let signalQueue = LinkedBlockingQueue<_SystemMessage>()
    /// Blocking linked queue, specialized for keeping only termination signals (so that we can assert terminations, independently of other signals)
    private let terminationsQueue = LinkedBlockingQueue<Signals.Terminated>()

    /// Last message received (by using an `expect...` call), by this probe.
    public var lastMessage: Message?

    /// Prepares and spawns a new test probe. Users should use `testKit.spawnTestProbe(...)` instead.
    internal init(
        spawn: (Behavior<ProbeCommands>) throws -> ActorRef<ProbeCommands>, settings: ActorTestKitSettings,
        file: StaticString = #file, line: UInt = #line
    ) {
        self.settings = settings

        let behavior: Behavior<ProbeCommands> = ActorTestProbe.behavior(
            messageQueue: self.messagesQueue,
            signalQueue: self.signalQueue,
            terminationsQueue: self.terminationsQueue
        )

        do {
            self.internalRef = try spawn(behavior)
        } catch {
            let _: Never = fatalErrorBacktrace("Failed to spawn \(ActorTestProbe<Message>.self): [\(error)]:\(String(reflecting: type(of: error)))", file: file, line: line)
        }

        self.name = self.internalRef.address.name

        let wrapRealMessages: (Message) -> ProbeCommands = { msg in
            ProbeCommands.realMessage(message: msg)
        }
        self.exposedRef = self.internalRef._unsafeUnwrapCell.actor!.messageAdapter(wrapRealMessages)
    }

    private static func behavior(
        messageQueue: LinkedBlockingQueue<Message>,
        signalQueue: LinkedBlockingQueue<_SystemMessage>, // TODO: maybe we don't need this one
        terminationsQueue: LinkedBlockingQueue<Signals.Terminated>
    ) -> Behavior<ProbeCommands> {
        Behavior<ProbeCommands>.receive { context, message in
            guard let cell = context.myself._unsafeUnwrapCell.actor else {
                throw TestProbeInitializationError.failedToObtainUnderlyingCell
            }

            switch message {
            case .realMessage(let msg):
                traceLog_Probe("Probe received: [\(msg)]:\(type(of: msg))")
                // real messages are stored directly
                messageQueue.enqueue(msg)
                return .same

            // probe commands:
            case .watchCommand(let who, let file, let line):
                cell.deathWatch.watch(watchee: who, with: nil, myself: context.myself, parent: cell._parent, file: file, line: line)
                return .same

            case .unwatchCommand(let who):
                cell.deathWatch.unwatch(watchee: who, myself: context.myself)
                return .same

            case .stopCommand:
                return .stop
            }
        }.receiveSignal { _, signal in
            traceLog_Probe("Probe received: [\(signal)]:\(type(of: signal))")
            switch signal {
            case let terminated as Signals.Terminated:
                terminationsQueue.enqueue(terminated)
                return .same
            default:
                return .unhandled
            }
        }
    }

    enum TestProbeInitializationError: Error {
        case failedToObtainUnderlyingCell
    }

    enum ExpectationError: Error {
        case noMessagesInQueue
        case notEnoughMessagesInQueue(actualCount: Int, expectedCount: Int)
        case withinDeadlineExceeded(timeout: TimeAmount)
        case timeoutAwaitingMessage(expected: AnyObject, timeout: TimeAmount)
    }
}

extension ActorTestProbe: CustomStringConvertible {
    public var description: String {
        let prettyTypeName = String(reflecting: Message.self).split(separator: ".").dropFirst().joined(separator: ".")
        return "ActorTestProbe<\(prettyTypeName)>(\(self.ref.address))"
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Expecting messages

extension ActorTestProbe {
    /// Expects a message to arrive at the TestProbe and returns it for further assertions.
    /// See also the `expectMessage(_:Message)` overload which provides automatic equality checking.
    ///
    /// - SeeAlso: `maybeExpectMessage(file:line:column:)` which does not fail upon encountering no message within the timeout.
    ///
    /// - Warning: Blocks the current thread until the `expectationTimeout` is exceeded or a message is received by the actor.
    public func expectMessage(file: StaticString = #file, line: UInt = #line, column: UInt = #column) throws -> Message {
        try self.expectMessage(within: self.expectationTimeout, file: file, line: line, column: column)
    }

    /// Expects a message to arrive at the TestProbe and returns it for further assertions.
    /// See also the `expectMessage(_:Message)` overload which provides automatic equality checking.
    /// - SeeAlso: `maybeExpectMessage(within:file:line:column:)` which does not fail upon encountering no message within the timeout.
    ///
    /// - Warning: Blocks the current thread until the `timeout` is exceeded or a message is received by the actor.
    public func expectMessage(within timeout: TimeAmount, file: StaticString = #file, line: UInt = #line, column: UInt = #column) throws -> Message {
        let callSite = CallSiteInfo(file: file, line: line, column: column, function: #function)
        do {
            return try self.receiveMessage(within: timeout)
        } catch {
            let message = "Did not receive message of type [\(Message.self)] within [\(timeout.prettyDescription)], error: \(error)"
            throw callSite.error(message)
        }
    }

    internal func receiveMessage(within timeout: TimeAmount) throws -> Message {
        let deadline = Deadline.fromNow(timeout)
        while deadline.hasTimeLeft() {
            guard let message = self.messagesQueue.poll(deadline.timeLeft) else {
                continue
            }
            self.lastMessage = message
            return message
        }

        throw ExpectationError.noMessagesInQueue
    }

    /// Allows for "fishing out" certain messages from the stream of incoming messages to this probe.
    /// Messages can be caught or ignored using the passed in function.
    ///
    /// Allows transforming the caught messages to `CaughtMessage` (e.g. extracting a specific payload from all incoming messages).
    /// If you need to aggregate the exact `Message` types, you prefer using `fishForMessages`.
    ///
    /// Once `MessageFishingDirective.catchComplete` or `MessageFishingDirective.complete` is returned,
    /// the function returns all so-far accumulated messages.
    public func fishFor<CaughtMessage>(
        _ type: CaughtMessage.Type, within timeout: TimeAmount,
        file: StaticString = #file, line: UInt = #line, column: UInt = #column,
        _ fisher: (Message) throws -> FishingDirective<CaughtMessage>
    ) throws -> [CaughtMessage] {
        let deadline = Deadline.fromNow(timeout)

        var caughtMessages: [CaughtMessage] = []
        while deadline.hasTimeLeft() {
            if let message = try self.maybeExpectMessage(within: deadline.timeLeft) {
                switch try fisher(message) {
                case .catchContinue(let caught):
                    caughtMessages.append(caught)
                case .catchComplete(let caught):
                    caughtMessages.append(caught)
                    return caughtMessages
                case .ignore:
                    ()
                case .complete:
                    return caughtMessages
                }
            }
        }

        if caughtMessages.isEmpty {
            throw self.error("No messages \(String(reflecting: type)) caught within \(timeout.prettyDescription)!", file: file, line: line, column: column)
        }

        return caughtMessages
    }

    public enum FishingDirective<CaughtMessage> {
        case catchContinue(CaughtMessage)
        case catchComplete(CaughtMessage)
        case ignore
        case complete
    }

    public enum MessageFishingError: Error {
        case noMessagesCaught
    }

    /// Allows for "fishing out" certain messages from the stream of incoming messages to this probe.
    /// Messages can be caught or ignored using the passed in function.
    ///
    /// The accumulated messages are assumed to be transforming the caught messages to `CaughtMessage` (e.g. extracting a specific payload from all incoming messages).
    /// If you need to aggregate the exact `Message` types, you prefer using `fishForMessages`.
    ///
    /// Once `MessageFishingDirective.catchComplete` or `MessageFishingDirective.complete` is returned,
    /// the function returns all so-far accumulated messages.
    public func fishForMessages(
        within timeout: TimeAmount,
        file: StaticString = #file, line: UInt = #line, column: UInt = #column,
        _ fisher: (Message) throws -> MessageFishingDirective
    ) throws -> [Message] {
        try self.fishFor(Message.self, within: timeout, file: file, line: line, column: column) { message in
            switch try fisher(message) {
            case .catchContinue:
                return .catchContinue(message)
            case .catchComplete:
                return .catchComplete(message)
            case .ignore:
                return .ignore
            case .complete:
                return .complete
            }
        }
    }

    public enum MessageFishingDirective {
        case catchContinue
        case catchComplete
        case ignore
        case complete
    }
}

extension ActorTestProbe {
    /// Expects a message to "maybe" arrive at the `ActorTestProbe` and returns it for further assertions,
    /// if no message arrives within the timeout (by default `expectationTimeout`) a `nil` value is returned.
    ///
    /// In general these the `maybeExpect` family of methods is more useful in loops or for testing optional replies,
    /// when a reply may or may not arrive (i.e. it is known to be racy).
    ///
    /// - SeeAlso: `expectMessage(file:line:column)` that throws and fails if no message is encountered during the timeout.
    ///
    /// - Warning: Blocks the current thread until the `expectationTimeout` is exceeded or a message is received by the actor.
    public func maybeExpectMessage() throws -> Message? {
        try self.maybeExpectMessage(within: self.expectationTimeout)
    }

    /// Expects a message to "maybe" arrive at the `ActorTestProbe` and returns it for further assertions,
    /// if no message arrives within the timeout (by default `expectationTimeout`) a `nil` value is returned.
    ///
    /// In general these the `maybeExpect` family of methods is more useful in loops or for testing optional replies,
    /// when a reply may or may not arrive (i.e. it is known to be racy).
    ///
    /// - SeeAlso: `expectMessage(within:file:line:column)` that throws and fails if no message is encountered during the timeout.
    ///
    /// - Warning: Blocks the current thread until the `timeout` is exceeded or a message is received by the actor.
    public func maybeExpectMessage(within timeout: TimeAmount) throws -> Message? {
        do {
            return try self.maybeReceiveMessage(within: timeout)
        } catch {
            return nil
        }
    }

    internal func maybeReceiveMessage(within timeout: TimeAmount) throws -> Message? {
        let deadline = Deadline.fromNow(timeout)
        while deadline.hasTimeLeft() {
            guard let message = self.messagesQueue.poll(deadline.timeLeft) else {
                continue
            }
            self.lastMessage = message
            return message
        }

        throw ExpectationError.noMessagesInQueue
    }
}

extension ActorTestProbe where Message: Equatable {
    /// Fails in nice readable ways:
    ///
    /// - Warning: Blocks the current thread until the `expectationTimeout` is exceeded or an message is received by the actor.
    ///
    ///
    /// Example output:
    ///
    ///     sact/Tests/DistributedActorsTestKitTests/ActorTestProbeTests.swift:35: error: -[DistributedActorsTestKitTests.ActorTestProbeTests test_testProbe_expectMessage_shouldFailWhenNoMessageSentWithinTimeout] : XCTAssertTrue failed -
    ///     try! probe.expectMessage("awaiting-forever")
    ///                ^~~~~~~~~~~~~~
    ///     error: Did not receive expected [awaiting-forever]:String within [1s], error: noMessagesInQueue
    ///
    public func expectMessage(_ message: Message, file: StaticString = #file, line: UInt = #line, column: UInt = #column) throws {
        try self.expectMessage(message, within: self.expectationTimeout, file: file, line: line, column: column)
    }

    public func expectMessage(_ message: Message, within timeout: TimeAmount, file: StaticString = #file, line: UInt = #line, column: UInt = #column) throws {
        let callSite = CallSiteInfo(file: file, line: line, column: column, function: #function)
        do {
            let receivedMessage = try self.receiveMessage(within: timeout)
            self.lastMessage = receivedMessage
            guard receivedMessage == message else {
                throw callSite.notEqualError(got: receivedMessage, expected: message)
            }
        } catch {
            let message = "Did not receive expected [\(message)]:\(type(of: message)) within [\(timeout.prettyDescription)], error: \(error)"
            throw callSite.error(message)
        }
    }

    public func expectMessageType<T>(_ type: T.Type, file: StaticString = #file, line: UInt = #line, column: UInt = #column) throws {
        try self.expectMessageType(type, within: self.expectationTimeout, file: file, line: line, column: column)
    }

    public func expectMessageType<T>(_ type: T.Type, within timeout: TimeAmount, file: StaticString = #file, line: UInt = #line, column: UInt = #column) throws {
        let callSite = CallSiteInfo(file: file, line: line, column: column, function: #function)

        let receivedMessage = try self.receiveMessage(within: timeout)
        self.lastMessage = receivedMessage
        guard receivedMessage is T else {
            throw callSite.notEqualError(got: receivedMessage, expected: type)
        }
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Expecting multiple messages

extension ActorTestProbe {
    /// Expects multiple messages to arrive at the TestProbe and returns it for further assertions.
    /// See also the `expectMessagesInAnyOrder([Message])` overload which provides automatic equality checking.
    ///
    /// - Warning: Blocks the current thread until the `expectationTimeout` is exceeded or an message is received by the actor.
    public func expectMessages(count: Int, file: StaticString = #file, line: UInt = #line, column: UInt = #column) throws -> [Message] {
        try self.expectMessages(count: count, within: self.expectationTimeout, file: file, line: line, column: column)
    }

    /// Expects multiple messages to arrive at the TestProbe and returns it for further assertions.
    /// See also the `expectMessagesInAnyOrder([Message])` overload which provides automatic equality checking.
    ///
    /// - Warning: Blocks the current thread until the `expectationTimeout` is exceeded or an message is received by the actor.
    public func expectMessages(count: Int, within timeout: TimeAmount, file: StaticString = #file, line: UInt = #line, column: UInt = #column) throws -> [Message] {
        let callSite = CallSiteInfo(file: file, line: line, column: column, function: #function)

        let deadline = Deadline.fromNow(timeout)

        var receivedMessages: [Message] = []
        do {
            receivedMessages.reserveCapacity(count)

            while deadline.hasTimeLeft() {
                do {
                    let message = try self.receiveMessage(within: deadline.timeLeft)
                    receivedMessages.append(message)
                    self.lastMessage = message

                    if receivedMessages.count == count {
                        return receivedMessages
                    }
                } catch {
                    switch error {
                    case ExpectationError.noMessagesInQueue: break
                    default: throw error
                    }
                }
            }

            throw ExpectationError.notEnoughMessagesInQueue(actualCount: receivedMessages.count, expectedCount: count)
        } catch {
            let message = "Did not receive expected messages (count: \(count)) of type [\(Message.self)] within [\(timeout.prettyDescription)], got: \(lineByLine: receivedMessages)\nerror: \(error)"
            throw callSite.error(message)
        }
    }
}

extension ActorTestProbe where Message: Equatable {
    public func expectMessagesInAnyOrder(_ _messages: [Message], file: StaticString = #file, line: UInt = #line, column: UInt = #column) throws {
        try self.expectMessagesInAnyOrder(_messages, within: self.expectationTimeout, file: file, line: line, column: column)
    }

    public func expectMessagesInAnyOrder(_ _messages: [Message], within timeout: TimeAmount, file: StaticString = #file, line: UInt = #line, column: UInt = #column) throws {
        var messages = _messages
        let callSite = CallSiteInfo(file: file, line: line, column: column, function: #function)
        var received: [Message] = []
        do {
            let deadline = Deadline.fromNow(timeout)

            while !messages.isEmpty {
                let receivedMessage = try self.receiveMessage(within: deadline.timeLeft)
                self.lastMessage = receivedMessage
                guard let index = messages.firstIndex(where: { $0 == receivedMessage }) else {
                    throw callSite.error("Received unexpected message [\(receivedMessage)]")
                }
                received.append(messages.remove(at: index))
            }
        } catch {
            let message = "Received only (in order) [\(received)], but did not receive expected [\(messages)]:\(String(reflecting: Message.self)) within [\(timeout.prettyDescription)], error: \(error)"
            throw callSite.error(message)
        }
    }
}

// ==== ------------------------------------------------------------------------------------------------------------
// MARK: Clearing buffered messages (for expectations)

extension ActorTestProbe {
    /// Clear any buffered messages from the probe's queue.
    ///
    /// Blocks until no more message remains to be dropped.
    /// Note that if the probe is concurrently being sent messages as it is clearing them, this may result in spinning forever,
    /// or for in-deterministic amounts of time.
    public func clearMessages() {
        do {
            while try self.maybeExpectMessage() != nil {
                () // dropping messages
            }
        } catch {
            () // no messages in queue; i.e. nothing to clear; we're good
        }
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: TestProbes can ReceivesMessages

extension ActorTestProbe: ReceivesMessages {
    public var address: ActorAddress {
        self.exposedRef.address
    }

    public func tell(_ message: Message, file: String = #file, line: UInt = #line) {
        self.exposedRef.tell(message, file: file, line: line)
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: TestProbes can intercept all messages send to a Behavior

public extension ActorTestProbe {
    // TODO: would be nice to be able to also intercept system messages hm...

    func interceptAllMessages(sentTo behavior: Behavior<Message>) -> Behavior<Message> {
        let interceptor: Interceptor<Message> = ProbeInterceptor(probe: self)
        return .intercept(behavior: behavior, with: interceptor)
    }
}

/// Allows intercepting messages
public final class ProbeInterceptor<Message: ActorMessage>: Interceptor<Message> {
    let probe: ActorTestProbe<Message>

    public init(probe: ActorTestProbe<Message>) {
        self.probe = probe
    }

    public final override func interceptMessage(target: Behavior<Message>, context: ActorContext<Message>, message: Message) throws -> Behavior<Message> {
        self.probe.tell(message)
        return try target.interpretMessage(context: context, message: message)
    }
}

extension ActorTestProbe {
    @discardableResult
    private func within<T>(_ timeout: TimeAmount, _ block: () throws -> T) throws -> T {
        // FIXME: implement by scheduling checks rather than spinning
        let deadline = Deadline.fromNow(timeout)
        var lastObservedError: Error?

        // TODO: make more async than seining like this, also with check interval rather than spin, or use the blocking queue properly
        while !deadline.isBefore(.now()) {
            do {
                let res: T = try block()
                return res
            } catch {
                // keep error, try again...
                lastObservedError = error
            }
        }

        if let lastError = lastObservedError {
            throw lastError
        } else {
            throw ExpectationError.withinDeadlineExceeded(timeout: timeout)
        }
    }

    // ==== ------------------------------------------------------------------------------------------------------------
    // MARK: Failure helpers

    /// Returns a failure with additional information of the probes last observed messages.
    /// Most useful as the `else` in an guard expression where the left hand side was an [expectMessage].
    ///
    /// Examples:
    ///
    ///     guard ... else { throw p.failure("failed to extract expected information") }
    ///     guard case let .spawned(child) = try p.expectMessage() else { throw p.failure() }
    public func error(_ message: String? = nil, file: StaticString = #file, line: UInt = #line, column: UInt = #column) -> Error {
        let callSite = CallSiteInfo(file: file, line: line, column: column, function: #function)

        var fullMessage: String = message ?? "ActorTestProbe failure."

        switch self.lastMessage {
        case .some(let m):
            fullMessage += " Last message observed was: [\(m)]."
        case .none:
            fullMessage += " No message was observed before this failure."
        }

        return callSite.error(fullMessage)
    }

    // ==== ------------------------------------------------------------------------------------------------------------
    // MARK: Expecting messages with matching/extracting callbacks

    /// Expects a message and applies the nested logic to extract values out of it.
    ///
    /// The callback MAY return `nil` in order to signal "this is not the expected message", or throw an error itself.
    // TODO: find a better name; it is not exactly "fish for message" though, that can ignore messages for a while, this one does not
    public func expectMessageMatching<T>(file: StaticString = #file, line: UInt = #line, column: UInt = #column, _ matchExtract: (Message) throws -> T?) throws -> T {
        let callSite = CallSiteInfo(file: file, line: line, column: column, function: #function)
        let timeout = self.expectationTimeout
        do {
            let receivedMessage: Message = try self.receiveMessage(within: timeout)
            guard let extracted = try matchExtract(receivedMessage) else {
                let message = "Received \(Message.self) message, however it did not pass the matching check, " +
                    "and did not produce the requested \(T.self)."
                throw callSite.error(message)
            }
            return extracted
        } catch {
            let message = "Did not receive matching [\(Message.self)] message within [\(timeout.prettyDescription)], error: \(error)"
            throw callSite.error(message)
        }
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Expecting no message/signal within a timeout

extension ActorTestProbe {
    /// Asserts that no message is received by the probe during the specified timeout.
    /// Useful for making sure that after some "terminal" message no other messages are sent.
    ///
    /// Warning: The method will block the current thread for the specified timeout.
    public func expectNoMessage(for timeout: TimeAmount, file: StaticString = #file, line: UInt = #line, column: UInt = #column) throws {
        let callSite = CallSiteInfo(file: file, line: line, column: column, function: #function)
        if let message = self.messagesQueue.poll(timeout) {
            let message = "Received unexpected message [\(message)]:\(type(of: message)). Did not expect to receive any messages for [\(timeout.prettyDescription)]."
            throw callSite.error(message)
        }
    }

    /// Asserts that no termination signals (specifically) are received by the probe during the specified timeout.
    ///
    /// Warning: The method will block the current thread for the specified timeout.
    public func expectNoTerminationSignal(for timeout: TimeAmount, file: StaticString = #file, line: UInt = #line, column: UInt = #column) throws {
        let callSite = CallSiteInfo(file: file, line: line, column: column, function: #function)
        if let termination = self.terminationsQueue.poll(timeout) {
            let message = "Received unexpected termination [\(termination)]. Did not expect to receive any termination for [\(timeout.prettyDescription)]."
            throw callSite.error(message)
        }
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Expecting signals

extension ActorTestProbe {
    /// Expects a signal to be enqueued to this actor within the default `expectationTimeout`.
    public func expectSignal(file: StaticString = #file, line: UInt = #line, column: UInt = #column) throws -> _SystemMessage {
        let callSite = CallSiteInfo(file: file, line: line, column: column, function: #function)

        let maybeGot: _SystemMessage? = self.signalQueue.poll(self.expectationTimeout)
        guard let got = maybeGot else {
            throw callSite.error("Expected Signal however no signal arrived within \(self.expectationTimeout.prettyDescription)")
        }
        return got
    }

    /// Expects the `expected` system message
    public func expectSignal(expected: _SystemMessage, file: StaticString = #file, line: UInt = #line, column: UInt = #column) throws {
        let callSite = CallSiteInfo(file: file, line: line, column: column, function: #function)

        let got: _SystemMessage = try self.expectSignal(file: file, line: line, column: column)
        if got != expected {
            throw callSite.notEqualError(got: got, expected: expected)
        }
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Death watch methods
extension ActorTestProbe {
    /// Instructs this probe to watch the passed in actor.
    /// The `watchee` actor is from now on being watched and we will receive `.terminated` signals about it.
    ///
    /// There is no difference between keeping the passed in reference or using the returned ref from this method.
    /// The actor is the being watched subject, not a specific reference to it.
    ///
    /// This enables it to use `expectTerminated` to await for the watched actors termination.
    ///
    /// - Returns: reference to the passed in `watchee` actor.
    /// - SeeAlso: `DeathWatch`
    @discardableResult
    public func watch<M>(_ watchee: ActorRef<M>, file: String = #file, line: UInt = #line) -> ActorRef<M> {
        self.internalRef.tell(ProbeCommands.watchCommand(who: watchee.asAddressable(), file: file, line: line))
        return watchee
    }

    /// Instructs this probe to unwatch the passed in reference.
    ///
    /// Note that unwatch MIGHT when used with testProbes since the probe may have already stored
    /// the `.terminated` signal in its signal assertion queue, which is not modified upon `unwatching`.
    /// If you want to avoid such race, you can implement your own small actor which performs the watching
    /// and forwards signals appropriately to a probe to trigger the assertions in the tests main thread.
    ///
    /// - Returns: reference to the passed in watchee actor.
    /// - SeeAlso: `DeathWatch`
    @discardableResult
    public func unwatch<M>(_ watchee: ActorRef<M>) -> ActorRef<M> {
        self.internalRef.tell(ProbeCommands.unwatchCommand(who: watchee.asAddressable()))
        return watchee
    }

    /// Returns the `Signals.Terminated` signal since one may want to perform additional assertions on the termination reason.
    ///
    /// - Warning: Remember to first `watch` the actor you are expecting termination for,
    ///            otherwise the termination signal will never be received.
    /// - Returns: the matched `.terminated` message
    /// - SeeAlso: `DeathWatch`
    @discardableResult
    // TODO: expectTermination(of: ...) maybe nicer wording?
    public func expectTerminated<T>(_ ref: ActorRef<T>, within timeout: TimeAmount? = nil, file: StaticString = #file, line: UInt = #line, column: UInt = #column) throws -> Signals.Terminated {
        let callSite = CallSiteInfo(file: file, line: line, column: column, function: #function)
        let timeout = timeout ?? self.expectationTimeout

        guard let terminated = self.terminationsQueue.poll(timeout) else {
            throw callSite.error("Expected [\(ref.address)] to terminate within \(timeout.prettyDescription)")
        }
        guard terminated.address == ref.address else {
            throw callSite.error("Expected [\(ref.address)] to terminate, but received [\(terminated.address)] terminated signal first instead. " +
                "This could be an ordering issue, inspect your signal order assumptions.")
        }

        return terminated // ok!
    }

    /// Awaits termination of all passed in actors in any order within the default `expectationTimeout`.
    ///
    /// - ***Warning**: Remember to first `watch` the actors you are expecting termination for,
    ///                 otherwise the termination signal will never be received.
    /// - SeeAlso: `DeathWatch`
    public func expectTerminatedInAnyOrder(_ refs: [AddressableActorRef], file: StaticString = #file, line: UInt = #line, column: UInt = #column) throws {
        let callSite = CallSiteInfo(file: file, line: line, column: column, function: #function)
        var pathSet: Set<ActorAddress> = Set(refs.map { $0.address })

        let deadline = Deadline.fromNow(self.expectationTimeout)
        while !pathSet.isEmpty, deadline.hasTimeLeft() {
            guard let terminated = self.terminationsQueue.poll(deadline.timeLeft) else {
                throw callSite.error("Expected [\(refs)] to terminate within \(self.expectationTimeout.prettyDescription)")
            }

            guard pathSet.remove(terminated.address) != nil else {
                throw callSite.error("Expected any of \(pathSet) to terminate, but received [\(terminated.address)] terminated signal first instead. " +
                    "This could be an ordering issue, inspect your signal order assumptions.")
            }
        }
    }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Test probe Lifecycle control

extension ActorTestProbe {
    /// Stops the test probe, asynchronously.
    ///
    /// - **Warning**: Since this action is asynchronous, in order to be certain that a probe has terminated before performing another task,
    ///              you may need to watch and expect it to terminate before moving on.
    public func stop() {
        // we send the stop command as normal message in order to not "overtake" other commands that were sent to it
        // not strictly required, but can yield more predictable results when used from tests after all
        self.internalRef.tell(.stopCommand)
    }
}
