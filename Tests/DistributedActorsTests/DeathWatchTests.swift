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
import DistributedActorsTestKit
import Foundation
import XCTest

final class DeathWatchTests: ActorSystemTestBase {
    // MARK: Termination watcher

    enum TerminationWatcherMessages {
        case watch(who: ActorRef<String>, notifyOnDeath: ActorRef<String>) // TODO: abstracting over this needs type erasure?
    }

    // MARK: stopping actors

    private func stopOnAnyMessage(probe: ActorRef<String>?) -> Behavior<StoppableRefMessage> {
        return .receive { context, message in
            switch message {
            case .stop:
                probe?.tell("I (\(context.path.name)) will now stop")
                return .stop
            }
        }
    }

    func test_watch_shouldTriggerTerminatedWhenWatchedActorStops() throws {
        let p: ActorTestProbe<String> = self.testKit.spawnTestProbe()
        let stoppableRef: ActorRef<StoppableRefMessage> = try system.spawn("stopMePlz0", self.stopOnAnyMessage(probe: p.ref))

        p.watch(stoppableRef)

        stoppableRef.tell(.stop)

        // the order of these messages is also guaranteed:
        // 1) first the dying actor has last chance to signal a message,
        try p.expectMessage("I (stopMePlz0) will now stop")
        // 2) and then terminated messages are sent:
        // try p.expectMessage("/user/terminationWatcher received .terminated for: /user/stopMePlz")
        try p.expectTerminated(stoppableRef)
    }

    func test_watchWith_shouldTriggerCustomMessageWhenWatchedActorStops() throws {
        let p: ActorTestProbe<String> = self.testKit.spawnTestProbe()
        let stoppableRef: ActorRef<StoppableRefMessage> = try system.spawn("stopMePlz0", self.stopOnAnyMessage(probe: p.ref))

        _ = try system.spawn("watcher", of: String.self, .setup { context in
            context.watch(stoppableRef, with: "terminated:\(stoppableRef.address.path)")
            stoppableRef.tell(.stop)
            return (Behavior<String>.receiveMessage { message in
                p.tell(message)
                return .same
            }).receiveSpecificSignal(Signals.Terminated.self) { _, terminated in
                p.tell("signal:\(terminated)") // should not be signalled (!)
                return .same
            }
        })

        // the order of these messages is also guaranteed:
        // 1) first the dying actor has last chance to signal a message,
        try p.expectMessage("I (stopMePlz0) will now stop")
        // 2) and then terminated messages are sent:
        try p.expectMessage("terminated:/user/stopMePlz0")
        // most notably, NOT the `signal:...` message
    }

    func test_watchWith_calledMultipleTimesShouldCarryTheLatestMessage() throws {
        let p: ActorTestProbe<String> = self.testKit.spawnTestProbe()
        let stoppableRef: ActorRef<StoppableRefMessage> = try system.spawn("stopMePlz0", self.stopOnAnyMessage(probe: p.ref))

        _ = try system.spawn("watcher", of: String.self, .setup { context in
            context.watch(stoppableRef, with: "terminated-1:\(stoppableRef.address.path)")
            context.watch(stoppableRef, with: "terminated-2:\(stoppableRef.address.path)")
            context.watch(stoppableRef, with: "terminated-3:\(stoppableRef.address.path)")
            stoppableRef.tell(.stop)
            return (Behavior<String>.receiveMessage { message in
                p.tell(message)
                return .same
            }).receiveSpecificSignal(Signals.Terminated.self) { _, terminated in
                p.tell("signal:\(terminated)") // should not be signalled (!)
                return .same
            }
        })

        // the order of these messages is also guaranteed:
        // 1) first the dying actor has last chance to signal a message,
        try p.expectMessage("I (stopMePlz0) will now stop")
        // 2) and then terminated messages are sent:
        try p.expectMessage("terminated-3:/user/stopMePlz0")
        // most notably, NOT the `signal:...` message
    }

    func test_watchWith_calledMultipleTimesShouldAllowGettingBackToSignalDelivery() throws {
        let p: ActorTestProbe<String> = self.testKit.spawnTestProbe()
        let stoppableRef: ActorRef<StoppableRefMessage> = try system.spawn("stopMePlz0", self.stopOnAnyMessage(probe: p.ref))

        _ = try system.spawn("watcher", of: String.self, .setup { context in
            context.watch(stoppableRef, with: "terminated-1:\(stoppableRef.address.path)")
            context.watch(stoppableRef, with: "terminated-2:\(stoppableRef.address.path)")
            context.watch(stoppableRef, with: nil)
            stoppableRef.tell(.stop)
            return (Behavior<String>.receiveMessage { message in
                p.tell(message) // should NOT be signalled, we're back to Signals
                return .same
            }).receiveSpecificSignal(Signals.Terminated.self) { _, terminated in
                p.tell("signal:\(terminated.address.path)") // should be signalled (!)
                return .same
            }
        })

        // the order of these messages is also guaranteed:
        // 1) first the dying actor has last chance to signal a message,
        try p.expectMessage("I (stopMePlz0) will now stop")
        // 2) and then terminated messages are sent:
        try p.expectMessage("signal:/user/stopMePlz0")
        // most notably, NOT the `signal:...` message
    }

    func test_watch_fromMultipleActors_shouldTriggerTerminatedWhenWatchedActorStops() throws {
        let p = self.testKit.spawnTestProbe("p", expecting: String.self)
        let p1 = self.testKit.spawnTestProbe("p1", expecting: String.self)
        let p2 = self.testKit.spawnTestProbe("p2", expecting: String.self)

        let stoppableRef: ActorRef<StoppableRefMessage> = try system.spawn("stopMePlz1", self.stopOnAnyMessage(probe: p.ref))

        p1.watch(stoppableRef)
        p2.watch(stoppableRef)

        stoppableRef.tell(.stop)
        stoppableRef.tell(.stop) // should result in dead letter
        stoppableRef.tell(.stop) // should result in dead letter
        stoppableRef.tell(.stop) // should result in dead letter

        try p.expectMessage("I (stopMePlz1) will now stop")
        // since the first message results in the actor becoming .stop
        // it should not be able to forward any new messages after the first one:
        try p.expectNoMessage(for: .milliseconds(100))

//    try p1.expectTerminated(stoppableRef)
//    try p2.expectTerminated(stoppableRef)
        Thread.sleep(.milliseconds(1000))
    }

    func test_watch_fromMultipleActors_shouldNotifyOfTerminationOnlyCurrentWatchers() throws {
        let p: ActorTestProbe<String> = self.testKit.spawnTestProbe("p")
        let p1: ActorTestProbe<String> = self.testKit.spawnTestProbe("p1")
        let p2: ActorTestProbe<String> = self.testKit.spawnTestProbe("p2")

        // p3 will not watch by itself, but serve as our observer for what our in-line defined watcher observes
        let p3_partnerOfNotActuallyWatching: ActorTestProbe<String> = self.testKit.spawnTestProbe("p3-not-really")

        let stoppableRef: ActorRef<StoppableRefMessage> = try system.spawn("stopMePlz2", self.stopOnAnyMessage(probe: p.ref))

        p1.watch(stoppableRef)
        p2.watch(stoppableRef)
        let notActuallyWatching: ActorRef<String> = try system.spawn("notActuallyWatching", .setup { context in
            context.watch(stoppableRef) // watching...
            context.unwatch(stoppableRef) // ... not *actually* watching!
            return Behavior<String>.receiveMessage { message in
                switch message {
                case "ping":
                    p3_partnerOfNotActuallyWatching.tell("pong")
                    return .same
                default:
                    fatalError("no other message is expected")
                }
            }
            .receiveSpecificSignal(Signals.Terminated.self) { _, _ in
                p3_partnerOfNotActuallyWatching.tell("whoops: actually DID receive terminated!")
                return .same
            }
        })

        // we need to perform this ping/pong dance since watch/unwatch are async, so we only know they have been sent
        // once we get a reply for a message from this actor (i.e. it has completed its setup).
        notActuallyWatching.tell("ping")
        try p3_partnerOfNotActuallyWatching.expectMessage("pong")

        stoppableRef.tell(.stop)

        try p.expectMessage("I (stopMePlz2) will now stop")

        try p1.expectTerminated(stoppableRef)
        try p2.expectTerminated(stoppableRef)
        try p3_partnerOfNotActuallyWatching.expectNoMessage(for: .milliseconds(1000)) // make su
    }

    func test_minimized_deathPact_shouldTriggerForWatchedActor() throws {
        let probe = self.testKit.spawnTestProbe("pp", expecting: String.self)

        let juliet = try system.spawn("juliet", Behavior<String>.receiveMessage { _ in
            .same
        })

        let romeo = try system.spawn("romeo", Behavior<String>.setup { context in
            context.watch(juliet)

            return .receiveMessage { msg in
                probe.ref.tell("reply:\(msg)")
                return .same
            }
        })

        probe.watch(juliet)
        probe.watch(romeo)

        romeo.tell("hi")
        try probe.expectMessage("reply:hi")

        // internal hacks
        let fakeTerminated: _SystemMessage = .terminated(ref: juliet.asAddressable(), existenceConfirmed: true)
        romeo._sendSystemMessage(fakeTerminated)

        try probe.expectTerminated(romeo)
    }

    func test_minimized_deathPact_shouldNotTriggerForActorThatWasWatchedButIsNotAnymoreWhenTerminatedArrives() throws {
        // Tests a very specific situation where romeo watches juliet, juliet terminates and sends .terminated
        // yet during that time, romeo unwatches her. This means that the .terminated message could arrive at
        // romeo AFTER the unwatch has been triggered. In this situation we DO NOT want to trigger the death pact,
        // since romeo by that time "does not care" about juliet anymore and should not die because of the .terminated.
        //
        // The .terminated message should also NOT be delivered to the .receiveSignal handler, it should be as if the watcher
        // never watched juliet to begin with. (This also is important so Swift Distributed Actors semantics are the same as what users would manually be able to to)

        let probe = self.testKit.spawnTestProbe("pp", expecting: String.self)

        let juliet = try system.spawn("juliet", Behavior<String>.receiveMessage { _ in
            .same
        })

        let romeo = try system.spawn("romeo", Behavior<String>.receive { context, message in
            switch message {
            case "watch":
                context.watch(juliet)
                probe.tell("reply:watch")
            case "unwatch":
                context.unwatch(juliet)
                probe.tell("reply:unwatch")
            default:
                fatalError("should not happen")
            }
            return .same
        }.receiveSignal { _, signal in
            if case let terminated as Signals.Terminated = signal {
                probe.tell("Unexpected terminated received!!! \(terminated)")
            }
            return .same
        })

        probe.watch(juliet)
        probe.watch(romeo)

        romeo.tell("watch")
        try probe.expectMessage("reply:watch")
        romeo.tell("unwatch")
        try probe.expectMessage("reply:unwatch")

        // internal hacks; we simulate that Juliet has terminated, and enqueued the .terminated before the unwatch managed to reach her
        let fakeTerminated: _SystemMessage = .terminated(ref: juliet.asAddressable(), existenceConfirmed: true)
        romeo._sendSystemMessage(fakeTerminated)

        // should NOT trigger the receiveSignal handler (which notifies the probe)
        try probe.expectNoMessage(for: .milliseconds(100))
    }

    func test_watch_anAlreadyStoppedActorRefShouldReplyWithTerminated() throws {
        let p: ActorTestProbe<String> = self.testKit.spawnTestProbe("alreadyDeadWatcherProbe")

        let alreadyDead: ActorRef<String> = try system.spawn("alreadyDead", .stop)

        p.watch(alreadyDead)
        try p.expectTerminated(alreadyDead)

        // even if a new actor comes in and performs the watch, it also should notice that `alreadyDead` is dead
        let p2: ActorTestProbe<String> = self.testKit.spawnTestProbe("alreadyDeadWatcherProbe2")
        p2.watch(alreadyDead)
        try p2.expectTerminated(alreadyDead)

        // `p` though should not accidentally get another .terminated when p2 installed the watch.
        try p.expectNoTerminationSignal(for: .milliseconds(200))
    }

    // MARK: Death pact

    func test_deathPact_shouldMakeWatcherKillItselfWhenWatcheeStops() throws {
        let romeo = try system.spawn("romeo", Behavior<RomeoMessage>.receive { context, message in
            switch message {
            case .pleaseWatch(let juliet, let probe):
                context.watch(juliet)
                probe.tell(.done)
                return .same
            }
        } /* NOT handling signal on purpose, we are in a Death Pact */ )

        let juliet = try system.spawn("juliet", Behavior<JulietMessage>.receiveMessage { message in
            switch message {
            case .takePoison:
                return .stop // "stop myself"
            }
        })

        let p = self.testKit.spawnTestProbe("p", expecting: Done.self)

        p.watch(juliet)
        p.watch(romeo)

        romeo.tell(.pleaseWatch(juliet: juliet, probe: p.ref))
        try p.expectMessage(.done)

        juliet.tell(.takePoison)

        try p.expectTerminatedInAnyOrder([juliet.asAddressable(), romeo.asAddressable()])
    }

    func test_deathPact_shouldMakeWatcherKillItselfWhenWatcheeThrows() throws {
        let romeo = try system.spawn("romeo", Behavior<RomeoMessage>.receive { context, message in
            switch message {
            case .pleaseWatch(let juliet, let probe):
                context.watch(juliet)
                probe.tell(.done)
                return .same
            }
        } /* NOT handling signal on purpose, we are in a Death Pact */ )

        let juliet = try system.spawn("juliet", Behavior<JulietMessage>.receiveMessage { message in
            switch message {
            case .takePoison:
                throw TakePoisonError() // "stop myself"
            }
        })

        let p = self.testKit.spawnTestProbe("p", expecting: Done.self)

        p.watch(juliet)
        p.watch(romeo)

        romeo.tell(.pleaseWatch(juliet: juliet, probe: p.ref))
        try p.expectMessage(.done)

        juliet.tell(.takePoison)

        try p.expectTerminatedInAnyOrder([juliet.asAddressable(), romeo.asAddressable()])
    }

    struct TakePoisonError: Error {}

    // ==== ------------------------------------------------------------------------------------------------------------
    // MARK: Watching dead letters ref

//    // FIXME: Make deadLetters a real thing, currently it is too hacky (i.e. this will crash):
//    func test_deadLetters_canBeWatchedAndAlwaysImmediatelyRepliesWithTerminated() throws {
//      let p: ActorTestProbe<Never> = .init(name: "deadLetter-probe", on: system)
//
//        p.watch(system.deadLetters)
//        try p.expectTerminated(system.deadLetters)
//    }

    func test_sendingToStoppedRef_shouldNotCrash() throws {
        let p: ActorTestProbe<String> = self.testKit.spawnTestProbe()
        let stoppableRef: ActorRef<StoppableRefMessage> = try system.spawn("stopMePlz2", self.stopOnAnyMessage(probe: p.ref))

        p.watch(stoppableRef)

        stoppableRef.tell(.stop)

        try p.expectTerminated(stoppableRef)

        stoppableRef.tell(.stop)
    }
}

private enum Done {
    case done
}

private enum RomeoMessage {
    case pleaseWatch(juliet: ActorRef<JulietMessage>, probe: ActorRef<Done>)
}

private enum JulietMessage {
    case takePoison
}

private enum StoppableRefMessage {
    case stop
}
