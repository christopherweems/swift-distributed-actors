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

import Swift Distributed ActorsActor
import XCTest
import NIOSSL
@testable import SwiftDistributedActorsActorTestKit

class ClusteringDocExamples: XCTestCase {
    func example_config_tls() throws {
        // tag::config_tls[]
        let system = ActorSystem("TestSystem") { settings in
            // ...
            settings.remoting.tls = TLSConfiguration.forServer(         // <1>
                certificateChain: [.file("/path/to/certificate.pem")],  // <2>
                privateKey: .file("/path/to/private-key.pem"),          // <3>
                certificateVerification: .fullVerification,             // <4>
                trustRoots: .file("/path/to/certificateChain.pem"))     // <5>
        }
        // end::config_tls[]

        defer { system.shutdown() }
    }

    func example_config_tls_passphrase() throws {
        // tag::config_tls_passphrase[]
        let system = ActorSystem("TestSystem") { settings in
            // ...
            settings.remoting.tlsPassphraseCallback = { setter in
                setter([UInt8]("password".utf8))
            }
        }
        // end::config_tls_passphrase[]

        defer { system.shutdown() }
    }
}