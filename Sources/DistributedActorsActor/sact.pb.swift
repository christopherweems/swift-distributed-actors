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

import Foundation
import SwiftProtobuf

// If the compiler emits an error on this type, it is because this file
// was generated by a version of the `protoc` Swift plug-in that is
// incompatible with the version of SwiftProtobuf to which you are linking.
// Please ensure that your are building against the same version of the API
// that was used to generate this file.
fileprivate struct _GeneratedWithProtocGenSwiftVersion: SwiftProtobuf.ProtobufAPIVersionCheck {
  struct _2: SwiftProtobuf.ProtobufAPIVersion_2 {}
  typealias Version = _2
}

/// The version is represented as 4 bytes:
/// - reserved: Can be used in the future for additional flags
/// - major
/// - minor
/// - patch
/// Because protobuf does not support values with less than 4 bytes, we
/// encode all values in a single uint32 and provide an extension to
/// retrieve the specific values.
struct ProtoVersion {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  var value: UInt32 = 0

  var unknownFields = SwiftProtobuf.UnknownStorage()

  init() {}
}

struct ProtoHandshake {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  var version: ProtoVersion {
    get {return _storage._version ?? ProtoVersion()}
    set {_uniqueStorage()._version = newValue}
  }
  /// Returns true if `version` has been explicitly set.
  var hasVersion: Bool {return _storage._version != nil}
  /// Clears the value of `version`. Subsequent reads from it will return its default value.
  mutating func clearVersion() {_uniqueStorage()._version = nil}

  var sender: ProtoUniqueAddress {
    get {return _storage._sender ?? ProtoUniqueAddress()}
    set {_uniqueStorage()._sender = newValue}
  }
  /// Returns true if `sender` has been explicitly set.
  var hasSender: Bool {return _storage._sender != nil}
  /// Clears the value of `sender`. Subsequent reads from it will return its default value.
  mutating func clearSender() {_uniqueStorage()._sender = nil}

  /// In the future we may want to add additional information
  /// about certain capabilities here. E.g. when a node supports
  /// faster transport like InfiniBand and the likes, so we can
  /// upgrade the connection in case both nodes support the fast
  /// transport.
  var receiver: ProtoUniqueAddress {
    get {return _storage._receiver ?? ProtoUniqueAddress()}
    set {_uniqueStorage()._receiver = newValue}
  }
  /// Returns true if `receiver` has been explicitly set.
  var hasReceiver: Bool {return _storage._receiver != nil}
  /// Clears the value of `receiver`. Subsequent reads from it will return its default value.
  mutating func clearReceiver() {_uniqueStorage()._receiver = nil}

  var unknownFields = SwiftProtobuf.UnknownStorage()

  init() {}

  fileprivate var _storage = _StorageClass.defaultInstance
}

struct ProtoEnvelope {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  var serializer: UInt32 = 0

  var payload: Data = SwiftProtobuf.Internal.emptyData

  var receiver: String = String()

  var unknownFields = SwiftProtobuf.UnknownStorage()

  init() {}
}

/// System messages have to be reliable, therefore they need to be acknowledged
/// by the receiving node.
struct ProtoSystemEnvelope {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  var serializer: UInt32 {
    get {return _storage._serializer}
    set {_uniqueStorage()._serializer = newValue}
  }

  var payload: Data {
    get {return _storage._payload}
    set {_uniqueStorage()._payload = newValue}
  }

  var sequenceNr: UInt64 {
    get {return _storage._sequenceNr}
    set {_uniqueStorage()._sequenceNr = newValue}
  }

  var sender: ProtoUniqueAddress {
    get {return _storage._sender ?? ProtoUniqueAddress()}
    set {_uniqueStorage()._sender = newValue}
  }
  /// Returns true if `sender` has been explicitly set.
  var hasSender: Bool {return _storage._sender != nil}
  /// Clears the value of `sender`. Subsequent reads from it will return its default value.
  mutating func clearSender() {_uniqueStorage()._sender = nil}

  var unknownFields = SwiftProtobuf.UnknownStorage()

  init() {}

  fileprivate var _storage = _StorageClass.defaultInstance
}

struct ProtoSystemAck {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  var sequenceNr: UInt64 {
    get {return _storage._sequenceNr}
    set {_uniqueStorage()._sequenceNr = newValue}
  }

  var sender: ProtoUniqueAddress {
    get {return _storage._sender ?? ProtoUniqueAddress()}
    set {_uniqueStorage()._sender = newValue}
  }
  /// Returns true if `sender` has been explicitly set.
  var hasSender: Bool {return _storage._sender != nil}
  /// Clears the value of `sender`. Subsequent reads from it will return its default value.
  mutating func clearSender() {_uniqueStorage()._sender = nil}

  var unknownFields = SwiftProtobuf.UnknownStorage()

  init() {}

  fileprivate var _storage = _StorageClass.defaultInstance
}

struct ProtoAddress {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  var `protocol`: String = String()

  var system: String = String()

  var hostname: String = String()

  var port: UInt32 = 0

  var unknownFields = SwiftProtobuf.UnknownStorage()

  init() {}
}

struct ProtoUniqueAddress {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  var address: ProtoAddress {
    get {return _storage._address ?? ProtoAddress()}
    set {_uniqueStorage()._address = newValue}
  }
  /// Returns true if `address` has been explicitly set.
  var hasAddress: Bool {return _storage._address != nil}
  /// Clears the value of `address`. Subsequent reads from it will return its default value.
  mutating func clearAddress() {_uniqueStorage()._address = nil}

  var uid: UInt32 {
    get {return _storage._uid}
    set {_uniqueStorage()._uid = newValue}
  }

  var unknownFields = SwiftProtobuf.UnknownStorage()

  init() {}

  fileprivate var _storage = _StorageClass.defaultInstance
}

// MARK: - Code below here is support for the SwiftProtobuf runtime.

extension ProtoVersion: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = "Version"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "value"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      switch fieldNumber {
      case 1: try decoder.decodeSingularUInt32Field(value: &self.value)
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if self.value != 0 {
      try visitor.visitSingularUInt32Field(value: self.value, fieldNumber: 1)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: ProtoVersion, rhs: ProtoVersion) -> Bool {
    if lhs.value != rhs.value {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension ProtoHandshake: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = "Handshake"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "version"),
    2: .same(proto: "sender"),
    3: .same(proto: "receiver"),
  ]

  fileprivate class _StorageClass {
    var _version: ProtoVersion? = nil
    var _sender: ProtoUniqueAddress? = nil
    var _receiver: ProtoUniqueAddress? = nil

    static let defaultInstance = _StorageClass()

    private init() {}

    init(copying source: _StorageClass) {
      _version = source._version
      _sender = source._sender
      _receiver = source._receiver
    }
  }

  fileprivate mutating func _uniqueStorage() -> _StorageClass {
    if !isKnownUniquelyReferenced(&_storage) {
      _storage = _StorageClass(copying: _storage)
    }
    return _storage
  }

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    _ = _uniqueStorage()
    try withExtendedLifetime(_storage) { (_storage: _StorageClass) in
      while let fieldNumber = try decoder.nextFieldNumber() {
        switch fieldNumber {
        case 1: try decoder.decodeSingularMessageField(value: &_storage._version)
        case 2: try decoder.decodeSingularMessageField(value: &_storage._sender)
        case 3: try decoder.decodeSingularMessageField(value: &_storage._receiver)
        default: break
        }
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    try withExtendedLifetime(_storage) { (_storage: _StorageClass) in
      if let v = _storage._version {
        try visitor.visitSingularMessageField(value: v, fieldNumber: 1)
      }
      if let v = _storage._sender {
        try visitor.visitSingularMessageField(value: v, fieldNumber: 2)
      }
      if let v = _storage._receiver {
        try visitor.visitSingularMessageField(value: v, fieldNumber: 3)
      }
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: ProtoHandshake, rhs: ProtoHandshake) -> Bool {
    if lhs._storage !== rhs._storage {
      let storagesAreEqual: Bool = withExtendedLifetime((lhs._storage, rhs._storage)) { (_args: (_StorageClass, _StorageClass)) in
        let _storage = _args.0
        let rhs_storage = _args.1
        if _storage._version != rhs_storage._version {return false}
        if _storage._sender != rhs_storage._sender {return false}
        if _storage._receiver != rhs_storage._receiver {return false}
        return true
      }
      if !storagesAreEqual {return false}
    }
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension ProtoEnvelope: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = "Envelope"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "serializer"),
    2: .same(proto: "payload"),
    3: .same(proto: "receiver"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      switch fieldNumber {
      case 1: try decoder.decodeSingularUInt32Field(value: &self.serializer)
      case 2: try decoder.decodeSingularBytesField(value: &self.payload)
      case 3: try decoder.decodeSingularStringField(value: &self.receiver)
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if self.serializer != 0 {
      try visitor.visitSingularUInt32Field(value: self.serializer, fieldNumber: 1)
    }
    if !self.payload.isEmpty {
      try visitor.visitSingularBytesField(value: self.payload, fieldNumber: 2)
    }
    if !self.receiver.isEmpty {
      try visitor.visitSingularStringField(value: self.receiver, fieldNumber: 3)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: ProtoEnvelope, rhs: ProtoEnvelope) -> Bool {
    if lhs.serializer != rhs.serializer {return false}
    if lhs.payload != rhs.payload {return false}
    if lhs.receiver != rhs.receiver {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension ProtoSystemEnvelope: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = "SystemEnvelope"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "serializer"),
    2: .same(proto: "payload"),
    3: .same(proto: "sequenceNr"),
    4: .same(proto: "sender"),
  ]

  fileprivate class _StorageClass {
    var _serializer: UInt32 = 0
    var _payload: Data = SwiftProtobuf.Internal.emptyData
    var _sequenceNr: UInt64 = 0
    var _sender: ProtoUniqueAddress? = nil

    static let defaultInstance = _StorageClass()

    private init() {}

    init(copying source: _StorageClass) {
      _serializer = source._serializer
      _payload = source._payload
      _sequenceNr = source._sequenceNr
      _sender = source._sender
    }
  }

  fileprivate mutating func _uniqueStorage() -> _StorageClass {
    if !isKnownUniquelyReferenced(&_storage) {
      _storage = _StorageClass(copying: _storage)
    }
    return _storage
  }

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    _ = _uniqueStorage()
    try withExtendedLifetime(_storage) { (_storage: _StorageClass) in
      while let fieldNumber = try decoder.nextFieldNumber() {
        switch fieldNumber {
        case 1: try decoder.decodeSingularUInt32Field(value: &_storage._serializer)
        case 2: try decoder.decodeSingularBytesField(value: &_storage._payload)
        case 3: try decoder.decodeSingularUInt64Field(value: &_storage._sequenceNr)
        case 4: try decoder.decodeSingularMessageField(value: &_storage._sender)
        default: break
        }
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    try withExtendedLifetime(_storage) { (_storage: _StorageClass) in
      if _storage._serializer != 0 {
        try visitor.visitSingularUInt32Field(value: _storage._serializer, fieldNumber: 1)
      }
      if !_storage._payload.isEmpty {
        try visitor.visitSingularBytesField(value: _storage._payload, fieldNumber: 2)
      }
      if _storage._sequenceNr != 0 {
        try visitor.visitSingularUInt64Field(value: _storage._sequenceNr, fieldNumber: 3)
      }
      if let v = _storage._sender {
        try visitor.visitSingularMessageField(value: v, fieldNumber: 4)
      }
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: ProtoSystemEnvelope, rhs: ProtoSystemEnvelope) -> Bool {
    if lhs._storage !== rhs._storage {
      let storagesAreEqual: Bool = withExtendedLifetime((lhs._storage, rhs._storage)) { (_args: (_StorageClass, _StorageClass)) in
        let _storage = _args.0
        let rhs_storage = _args.1
        if _storage._serializer != rhs_storage._serializer {return false}
        if _storage._payload != rhs_storage._payload {return false}
        if _storage._sequenceNr != rhs_storage._sequenceNr {return false}
        if _storage._sender != rhs_storage._sender {return false}
        return true
      }
      if !storagesAreEqual {return false}
    }
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension ProtoSystemAck: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = "SystemAck"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "sequenceNr"),
    2: .same(proto: "sender"),
  ]

  fileprivate class _StorageClass {
    var _sequenceNr: UInt64 = 0
    var _sender: ProtoUniqueAddress? = nil

    static let defaultInstance = _StorageClass()

    private init() {}

    init(copying source: _StorageClass) {
      _sequenceNr = source._sequenceNr
      _sender = source._sender
    }
  }

  fileprivate mutating func _uniqueStorage() -> _StorageClass {
    if !isKnownUniquelyReferenced(&_storage) {
      _storage = _StorageClass(copying: _storage)
    }
    return _storage
  }

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    _ = _uniqueStorage()
    try withExtendedLifetime(_storage) { (_storage: _StorageClass) in
      while let fieldNumber = try decoder.nextFieldNumber() {
        switch fieldNumber {
        case 1: try decoder.decodeSingularUInt64Field(value: &_storage._sequenceNr)
        case 2: try decoder.decodeSingularMessageField(value: &_storage._sender)
        default: break
        }
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    try withExtendedLifetime(_storage) { (_storage: _StorageClass) in
      if _storage._sequenceNr != 0 {
        try visitor.visitSingularUInt64Field(value: _storage._sequenceNr, fieldNumber: 1)
      }
      if let v = _storage._sender {
        try visitor.visitSingularMessageField(value: v, fieldNumber: 2)
      }
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: ProtoSystemAck, rhs: ProtoSystemAck) -> Bool {
    if lhs._storage !== rhs._storage {
      let storagesAreEqual: Bool = withExtendedLifetime((lhs._storage, rhs._storage)) { (_args: (_StorageClass, _StorageClass)) in
        let _storage = _args.0
        let rhs_storage = _args.1
        if _storage._sequenceNr != rhs_storage._sequenceNr {return false}
        if _storage._sender != rhs_storage._sender {return false}
        return true
      }
      if !storagesAreEqual {return false}
    }
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension ProtoAddress: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = "Address"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "protocol"),
    2: .same(proto: "system"),
    3: .same(proto: "hostname"),
    4: .same(proto: "port"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      switch fieldNumber {
      case 1: try decoder.decodeSingularStringField(value: &self.`protocol`)
      case 2: try decoder.decodeSingularStringField(value: &self.system)
      case 3: try decoder.decodeSingularStringField(value: &self.hostname)
      case 4: try decoder.decodeSingularUInt32Field(value: &self.port)
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if !self.`protocol`.isEmpty {
      try visitor.visitSingularStringField(value: self.`protocol`, fieldNumber: 1)
    }
    if !self.system.isEmpty {
      try visitor.visitSingularStringField(value: self.system, fieldNumber: 2)
    }
    if !self.hostname.isEmpty {
      try visitor.visitSingularStringField(value: self.hostname, fieldNumber: 3)
    }
    if self.port != 0 {
      try visitor.visitSingularUInt32Field(value: self.port, fieldNumber: 4)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: ProtoAddress, rhs: ProtoAddress) -> Bool {
    if lhs.`protocol` != rhs.`protocol` {return false}
    if lhs.system != rhs.system {return false}
    if lhs.hostname != rhs.hostname {return false}
    if lhs.port != rhs.port {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension ProtoUniqueAddress: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = "UniqueAddress"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "address"),
    2: .same(proto: "uid"),
  ]

  fileprivate class _StorageClass {
    var _address: ProtoAddress? = nil
    var _uid: UInt32 = 0

    static let defaultInstance = _StorageClass()

    private init() {}

    init(copying source: _StorageClass) {
      _address = source._address
      _uid = source._uid
    }
  }

  fileprivate mutating func _uniqueStorage() -> _StorageClass {
    if !isKnownUniquelyReferenced(&_storage) {
      _storage = _StorageClass(copying: _storage)
    }
    return _storage
  }

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    _ = _uniqueStorage()
    try withExtendedLifetime(_storage) { (_storage: _StorageClass) in
      while let fieldNumber = try decoder.nextFieldNumber() {
        switch fieldNumber {
        case 1: try decoder.decodeSingularMessageField(value: &_storage._address)
        case 2: try decoder.decodeSingularUInt32Field(value: &_storage._uid)
        default: break
        }
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    try withExtendedLifetime(_storage) { (_storage: _StorageClass) in
      if let v = _storage._address {
        try visitor.visitSingularMessageField(value: v, fieldNumber: 1)
      }
      if _storage._uid != 0 {
        try visitor.visitSingularUInt32Field(value: _storage._uid, fieldNumber: 2)
      }
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: ProtoUniqueAddress, rhs: ProtoUniqueAddress) -> Bool {
    if lhs._storage !== rhs._storage {
      let storagesAreEqual: Bool = withExtendedLifetime((lhs._storage, rhs._storage)) { (_args: (_StorageClass, _StorageClass)) in
        let _storage = _args.0
        let rhs_storage = _args.1
        if _storage._address != rhs_storage._address {return false}
        if _storage._uid != rhs_storage._uid {return false}
        return true
      }
      if !storagesAreEqual {return false}
    }
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}