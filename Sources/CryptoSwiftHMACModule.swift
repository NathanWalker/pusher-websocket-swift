// This is based on https://github.com/krzyzanowskim/CryptoSwift with modifications
// specific to the use case of PusherSwift.
//
// File created by running:
// cat Sources/CryptoSwift/Array+Extension.swift Sources/CryptoSwift/Authenticator.swift Sources/CryptoSwift/BatchedCollection.swift Sources/CryptoSwift/Bit.swift Sources/CryptoSwift/CSArrayType+Extensions.swift Sources/CryptoSwift/Digest.swift Sources/CryptoSwift/DigestType.swift Sources/CryptoSwift/Generics.swift Sources/CryptoSwift/Foundation/CSArrayType+Foundation.swift Sources/CryptoSwift/Foundation/Data+Extension.swift Sources/CryptoSwift/Foundation/HMAC+Foundation.swift Sources/CryptoSwift/Foundation/Utils+Foundation.swift Sources/CryptoSwift/HMAC.swift Sources/CryptoSwift/Int+Extension.swift Sources/CryptoSwift/NoPadding.swift Sources/CryptoSwift/Padding.swift Sources/CryptoSwift/RandomBytesSequence.swift Sources/CryptoSwift/SecureBytes.swift Sources/CryptoSwift/SHA2.swift Sources/CryptoSwift/String+Extension.swift Sources/CryptoSwift/UInt8+Extension.swift Sources/CryptoSwift/UInt16+Extension.swift Sources/CryptoSwift/UInt32+Extension.swift Sources/CryptoSwift/UInt64+Extension.swift Sources/CryptoSwift/Updatable.swift Sources/CryptoSwift/Utils.swift Sources/CryptoSwift/ZeroPadding.swift > HCCrypto.swift
// in a clone of the CryptoSwift project. Then removing anything not related to sha256 / sha512.
//
// Then made otherwise public API internal so as to avoid collisions
//
// ---------------------------------------
//
//  ArrayExtension.swift
//  CryptoSwift
//
//  Copyright (C) 2014-2017 Krzyżanowski <marcin@krzyzanowskim.com>
//  This software is provided 'as-is', without any express or implied warranty.
//
//  In no event will the authors be held liable for any damages arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
//  - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
//  - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//  - This notice may not be removed or altered from any source or binary distribution.
//

extension Array {
    init(reserveCapacity: Int) {
        self = Array<Element>()
        self.reserveCapacity(reserveCapacity)
    }
}

extension Array {

    /** split in chunks with given chunk size */
    internal func chunks(size chunksize: Int) -> Array<Array<Element>> {
        var words = Array<Array<Element>>()
        words.reserveCapacity(self.count / chunksize)
        for idx in stride(from: chunksize, through: self.count, by: chunksize) {
            words.append(Array(self[idx - chunksize ..< idx])) // slow for large table
        }
        let remainder = self.suffix(self.count % chunksize)
        if !remainder.isEmpty {
            words.append(Array(remainder))
        }
        return words
    }
}

extension Array where Element == UInt8 {

    internal init(hex: String) {
        self.init(reserveCapacity: hex.unicodeScalars.lazy.underestimatedCount)
        var buffer:UInt8?
        var skip = hex.hasPrefix("0x") ? 2 : 0
        for char in hex.unicodeScalars.lazy {
            guard skip == 0 else {
                skip -= 1
                continue
            }
            guard char.value >= 48 && char.value <= 102 else {
                self.removeAll()
                return
            }
            let v:UInt8
            let c:UInt8 = UInt8(char.value)
            switch c{
            case let c where c <= 57:
                v = c - 48
            case let c where c >= 65 && c <= 70:
                v = c - 55
            case let c where c >= 97:
                v = c - 87
            default:
                self.removeAll()
                return
            }
            if let b = buffer {
                self.append(b << 4 | v)
                buffer = nil
            } else {
                buffer = v
            }
        }
        if let b = buffer {
            self.append(b)
        }
    }

}
//
//  MAC.swift
//  CryptoSwift
//
//  Copyright (C) 2014-2017 Krzyżanowski <marcin@krzyzanowskim.com>
//  This software is provided 'as-is', without any express or implied warranty.
//
//  In no event will the authors be held liable for any damages arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
//  - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
//  - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//  - This notice may not be removed or altered from any source or binary distribution.
//

/// Message authentication code.
internal protocol Authenticator {
    /// Calculate Message Authentication Code (MAC) for message.
    func authenticate(_ bytes: Array<UInt8>) throws -> Array<UInt8>
}
//
//  BatchedCollection.swift
//  CryptoSwift
//
//  Copyright (C) 2014-2017 Krzyżanowski <marcin@krzyzanowskim.com>
//  This software is provided 'as-is', without any express or implied warranty.
//
//  In no event will the authors be held liable for any damages arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
//  - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
//  - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//  - This notice may not be removed or altered from any source or binary distribution.
//

struct BatchedCollectionIndex<Base: Collection> {
    let range: Range<Base.Index>
}

extension BatchedCollectionIndex: Comparable {
    static func ==<Base>(lhs: BatchedCollectionIndex<Base>, rhs: BatchedCollectionIndex<Base>) -> Bool {
        return lhs.range.lowerBound == rhs.range.lowerBound
    }
    static func < <Base>(lhs: BatchedCollectionIndex<Base>, rhs: BatchedCollectionIndex<Base>) -> Bool {
        return lhs.range.lowerBound < rhs.range.lowerBound
    }
}

protocol BatchedCollectionType: Collection {
    associatedtype Base: Collection
}

struct BatchedCollection<Base: Collection>: Collection {
    let base: Base
    let size: Base.IndexDistance
    typealias Index = BatchedCollectionIndex<Base>
    private func nextBreak(after idx: Base.Index) -> Base.Index {
        return base.index(idx, offsetBy: size, limitedBy: base.endIndex)
            ?? base.endIndex
    }
    var startIndex: Index {
        return Index(range: base.startIndex..<nextBreak(after: base.startIndex))
    }
    var endIndex: Index {
        return Index(range: base.endIndex..<base.endIndex)
    }
    func index(after idx: Index) -> Index {
        return Index(range: idx.range.upperBound..<nextBreak(after: idx.range.upperBound))
    }
    subscript(idx: Index) -> Base.SubSequence {
        return base[idx.range]
    }
}

extension Collection {
    func batched(by size: IndexDistance) -> BatchedCollection<Self> {
        return BatchedCollection(base: self, size: size)
    }
}
//
//  Bit.swift
//  CryptoSwift
//
//  Copyright (C) 2014-2017 Krzyżanowski <marcin@krzyzanowskim.com>
//  This software is provided 'as-is', without any express or implied warranty.
//
//  In no event will the authors be held liable for any damages arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
//  - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
//  - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//  - This notice may not be removed or altered from any source or binary distribution.
//

internal enum Bit: Int {
    case zero
    case one
}

extension Bit {

    func inverted() -> Bit {
        return self == .zero ? .one : .zero
    }
}
//
//  _ArrayType+Extensions.swift
//  CryptoSwift
//
//  Copyright (C) 2014-2017 Krzyżanowski <marcin@krzyzanowskim.com>
//  This software is provided 'as-is', without any express or implied warranty.
//
//  In no event will the authors be held liable for any damages arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
//  - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
//  - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//  - This notice may not be removed or altered from any source or binary distribution.
//

internal protocol CSArrayType: RangeReplaceableCollection {
    func cs_arrayValue() -> [Iterator.Element]
}

extension Array: CSArrayType {

    internal func cs_arrayValue() -> [Iterator.Element] {
        return self
    }
}

internal extension CSArrayType where Iterator.Element == UInt8 {

    internal func toHexString() -> String {
        return self.lazy.reduce("") {
            var s = String($1, radix: 16)
            if s.count == 1 {
                s = "0" + s
            }
            return $0 + s
        }
    }
}

internal extension CSArrayType where Iterator.Element == UInt8 {
    internal func sha256() -> [Iterator.Element] {
        return Digest.sha256(cs_arrayValue())
    }

    internal func sha512() -> [Iterator.Element] {
        return Digest.sha512(cs_arrayValue())
    }

    internal func sha2(_ variant: SHA2.Variant) -> [Iterator.Element] {
        return Digest.sha2(cs_arrayValue(), variant: variant)
    }

    internal func authenticate<A: Authenticator>(with authenticator: A) throws -> [Iterator.Element] {
        return try authenticator.authenticate(cs_arrayValue())
    }
}
//
//  Hash.swift
//  CryptoSwift
//
//  Copyright (C) 2014-2017 Krzyżanowski <marcin@krzyzanowskim.com>
//  This software is provided 'as-is', without any express or implied warranty.
//
//  In no event will the authors be held liable for any damages arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
//  - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
//  - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//  - This notice may not be removed or altered from any source or binary distribution.
//

@available(*, deprecated: 0.6.0, renamed: "Digest")
internal typealias Hash = Digest

/// Hash functions to calculate Digest.
internal struct Digest {
    /// Calculate SHA2-256 Digest
    /// - parameter bytes: input message
    /// - returns: Digest bytes
    internal static func sha256(_ bytes: Array<UInt8>) -> Array<UInt8> {
        return sha2(bytes, variant: .sha256)
    }

    /// Calculate SHA2-512 Digest
    /// - parameter bytes: input message
    /// - returns: Digest bytes
    internal static func sha512(_ bytes: Array<UInt8>) -> Array<UInt8> {
        return sha2(bytes, variant: .sha512)
    }

    /// Calculate SHA2 Digest
    /// - parameter bytes: input message
    /// - parameter variant: SHA-2 variant
    /// - returns: Digest bytes
    internal static func sha2(_ bytes: Array<UInt8>, variant: SHA2.Variant) -> Array<UInt8> {
        return SHA2(variant: variant).calculate(for: bytes)
    }
}
//
//  Digest.swift
//  CryptoSwift
//
//  Copyright (C) 2014-2017 Krzyżanowski <marcin@krzyzanowskim.com>
//  This software is provided 'as-is', without any express or implied warranty.
//
//  In no event will the authors be held liable for any damages arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
//  - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
//  - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//  - This notice may not be removed or altered from any source or binary distribution.
//

internal protocol DigestType {
    func calculate(for bytes: Array<UInt8>) -> Array<UInt8>
}
//
//  Generics.swift
//  CryptoSwift
//
//  Copyright (C) 2014-2017 Krzyżanowski <marcin@krzyzanowskim.com>
//  This software is provided 'as-is', without any express or implied warranty.
//
//  In no event will the authors be held liable for any damages arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
//  - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
//  - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//  - This notice may not be removed or altered from any source or binary distribution.
//

/** build bit pattern from array of bits */
@_specialize(where T == UInt8)
func integerFrom<T: FixedWidthInteger>(_ bits: Array<Bit>) -> T {
    var bitPattern: T = 0
    for idx in bits.indices {
        if bits[idx] == Bit.one {
            let bit = T(UInt64(1) << UInt64(idx))
            bitPattern = bitPattern | bit
        }
    }
    return bitPattern
}

/// Array of bytes. Caution: don't use directly because generic is slow.
///
/// - parameter value: integer value
/// - parameter length: length of output array. By default size of value type
///
/// - returns: Array of bytes
@_specialize(where T == Int)
@_specialize(where T == UInt16)
@_specialize(where T == UInt32)
@_specialize(where T == UInt64)
func arrayOfBytes<T: FixedWidthInteger>(value: T, length totalBytes: Int = MemoryLayout<T>.size) -> Array<UInt8> {
    let valuePointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
    valuePointer.pointee = value

    let bytesPointer = UnsafeMutablePointer<UInt8>(OpaquePointer(valuePointer))
    var bytes = Array<UInt8>(repeating: 0, count: totalBytes)
    for j in 0 ..< min(MemoryLayout<T>.size, totalBytes) {
        bytes[totalBytes - 1 - j] = (bytesPointer + j).pointee
    }

    valuePointer.deinitialize()
    valuePointer.deallocate(capacity: 1)

    return bytes
}
//
//  CSArrayType+Foundation.swift
//  CryptoSwift
//
//  Copyright (C) 2014-2017 Krzyżanowski <marcin@krzyzanowskim.com>
//  This software is provided 'as-is', without any express or implied warranty.
//
//  In no event will the authors be held liable for any damages arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
//  - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
//  - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//  - This notice may not be removed or altered from any source or binary distribution.
//

import Foundation

internal extension CSArrayType where Iterator.Element == UInt8 {

    internal func toBase64() -> String? {
        guard let bytesArray = self as? Array<UInt8> else {
            return nil
        }

        return Data(bytes: bytesArray).base64EncodedString()
    }

    internal init(base64: String) {
        self.init()

        guard let decodedData = Data(base64Encoded: base64) else {
            return
        }

        self.append(contentsOf: decodedData.bytes)
    }
}
//
//  PGPDataExtension.swift
//  SwiftPGP
//
//  Copyright (C) 2014-2017 Krzyżanowski <marcin@krzyzanowskim.com>
//  This software is provided 'as-is', without any express or implied warranty.
//
//  In no event will the authors be held liable for any damages arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
//  - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
//  - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//  - This notice may not be removed or altered from any source or binary distribution.
//

import Foundation

extension Data {

    /// Two octet checksum as defined in RFC-4880. Sum of all octets, mod 65536
    internal func checksum() -> UInt16 {
        var s: UInt32 = 0
        var bytesArray = self.bytes
        for i in 0 ..< bytesArray.count {
            s = s + UInt32(bytesArray[i])
        }
        s = s % 65536
        return UInt16(s)
    }

    internal func sha256() -> Data {
        return Data(bytes: Digest.sha256(self.bytes))
    }

    internal func sha512() -> Data {
        return Data(bytes: Digest.sha512(self.bytes))
    }

    internal func authenticate(with authenticator: Authenticator) throws -> Data {
        return Data(bytes: try authenticator.authenticate(self.bytes))
    }
}

extension Data {

    internal var bytes: Array<UInt8> {
        return Array(self)
    }

    internal func toHexString() -> String {
        return self.bytes.toHexString()
    }
}
//
//  HMAC+Foundation.swift
//  CryptoSwift
//
//  Copyright (C) 2014-2017 Krzyżanowski <marcin@krzyzanowskim.com>
//  This software is provided 'as-is', without any express or implied warranty.
//
//  In no event will the authors be held liable for any damages arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
//  - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
//  - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//  - This notice may not be removed or altered from any source or binary distribution.
//

import Foundation

extension HMAC {

    internal convenience init(key: String, variant: HMAC.Variant = .sha256) throws {
        guard let kkey = key.data(using: String.Encoding.utf8, allowLossyConversion: false)?.bytes else {
            throw Error.invalidInput
        }

        self.init(key: kkey, variant: variant)
    }
}
//
//  Utils+Foundation.swift
//  CryptoSwift
//
//  Copyright (C) 2014-2017 Krzyżanowski <marcin@krzyzanowskim.com>
//  This software is provided 'as-is', without any express or implied warranty.
//
//  In no event will the authors be held liable for any damages arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
//  - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
//  - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//  - This notice may not be removed or altered from any source or binary distribution.
//

import Foundation

func perf(_ text: String, closure: () -> Void) {
    let measurementStart = Date()

    closure()

    let measurementStop = Date()
    let executionTime = measurementStop.timeIntervalSince(measurementStart)

    print("\(text) \(executionTime)")
}
//
//  HMAC.swift
//  CryptoSwift
//
//  Copyright (C) 2014-2017 Krzyżanowski <marcin@krzyzanowskim.com>
//  This software is provided 'as-is', without any express or implied warranty.
//
//  In no event will the authors be held liable for any damages arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
//  - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
//  - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//  - This notice may not be removed or altered from any source or binary distribution.
//

internal final class HMAC: Authenticator {

    internal enum Error: Swift.Error {
        case authenticateError
        case invalidInput
    }

    internal enum Variant {
        case sha256,sha512

        var digestLength: Int {
            switch (self) {
            case .sha256:
                return SHA2.Variant.sha256.digestLength
            case .sha512:
                return SHA2.Variant.sha512.digestLength
            }
        }

        func calculateHash(_ bytes: Array<UInt8>) -> Array<UInt8>? {
            switch (self) {
            case .sha256:
                return Digest.sha256(bytes)
            case .sha512:
                return Digest.sha512(bytes)
            }
        }

        func blockSize() -> Int {
            switch self {
            case .sha256:
                return 64
            case .sha512:
                return 128
            }
        }
    }

    var key: Array<UInt8>
    let variant: Variant

    internal init(key: Array<UInt8>, variant: HMAC.Variant = .sha256) {
        self.variant = variant
        self.key = key

        if key.count > variant.blockSize() {
            if let hash = variant.calculateHash(key) {
                self.key = hash
            }
        }

        if key.count < variant.blockSize() {
            self.key = ZeroPadding().add(to: key, blockSize: variant.blockSize())
        }
    }

    // MARK: Authenticator

    internal func authenticate(_ bytes: Array<UInt8>) throws -> Array<UInt8> {
        var opad = Array<UInt8>(repeating: 0x5c, count: variant.blockSize())
        for idx in key.indices {
            opad[idx] = key[idx] ^ opad[idx]
        }
        var ipad = Array<UInt8>(repeating: 0x36, count: variant.blockSize())
        for idx in key.indices {
            ipad[idx] = key[idx] ^ ipad[idx]
        }

        guard let ipadAndMessageHash = variant.calculateHash(ipad + bytes),
            let result = variant.calculateHash(opad + ipadAndMessageHash) else {
            throw Error.authenticateError
        }

        // return Array(result[0..<10]) // 80 bits
        return result
    }
}
//
//  IntExtension.swift
//  CryptoSwift
//
//  Created by Marcin Krzyzanowski on 12/08/14.
//  Copyright (C) 2014-2017 Krzyżanowski <marcin@krzyzanowskim.com>
//  This software is provided 'as-is', without any express or implied warranty.
//
//  In no event will the authors be held liable for any damages arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
//  - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
//  - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//  - This notice may not be removed or altered from any source or binary distribution.
//

#if os(Linux) || os(Android) || os(FreeBSD)
    import Glibc
#else
    import Darwin
#endif

/* array of bits */
extension Int {

    init(bits: [Bit]) {
        self.init(bitPattern: integerFrom(bits) as UInt)
    }
}

/* array of bytes */
extension Int {

    /** Int with collection of bytes (little-endian) */
    // init<T: Collection>(bytes: T) where T.Iterator.Element == UInt8, T.Index == Int {
    //    self = bytes.toInteger()
    // }

    /** Array of bytes with optional padding */
    func bytes(totalBytes: Int = MemoryLayout<Int>.size) -> Array<UInt8> {
        return arrayOfBytes(value: self, length: totalBytes)
    }
}
//
//  NoPadding.swift
//  CryptoSwift
//
//  Copyright (C) 2014-2017 Krzyżanowski <marcin@krzyzanowskim.com>
//  This software is provided 'as-is', without any express or implied warranty.
//
//  In no event will the authors be held liable for any damages arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
//  - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
//  - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//  - This notice may not be removed or altered from any source or binary distribution.
//

internal struct NoPadding: Padding {

    internal init() {
    }

    internal func add(to data: Array<UInt8>, blockSize: Int) -> Array<UInt8> {
        return data
    }

    internal func remove(from data: Array<UInt8>, blockSize: Int?) -> Array<UInt8> {
        return data
    }
}
//
//  Padding.swift
//  CryptoSwift
//
//  Copyright (C) 2014-2017 Krzyżanowski <marcin@krzyzanowskim.com>
//  This software is provided 'as-is', without any express or implied warranty.
//
//  In no event will the authors be held liable for any damages arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
//  - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
//  - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//  - This notice may not be removed or altered from any source or binary distribution.
//

internal protocol Padding {
    func add(to: Array<UInt8>, blockSize: Int) -> Array<UInt8>
    func remove(from: Array<UInt8>, blockSize: Int?) -> Array<UInt8>
}
//
//  RandomBytesSequence.swift
//  CryptoSwift
//
//  Copyright (C) 2014-2017 Krzyżanowski <marcin@krzyzanowskim.com>
//  This software is provided 'as-is', without any express or implied warranty.
//
//  In no event will the authors be held liable for any damages arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
//  - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
//  - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//  - This notice may not be removed or altered from any source or binary distribution.
//

#if os(Linux) || os(Android) || os(FreeBSD)
    import Glibc
#else
    import Darwin
#endif

struct RandomBytesSequence: Sequence {
    let size: Int

    func makeIterator() -> AnyIterator<UInt8> {
        var count = 0
        return AnyIterator<UInt8>.init({ () -> UInt8? in
            if count >= self.size {
                return nil
            }
            count = count + 1

            #if os(Linux) || os(Android) || os(FreeBSD)
                let fd = open("/dev/urandom", O_RDONLY)
                if fd <= 0 {
                    return nil
                }

                var value: UInt8 = 0
                let result = read(fd, &value, MemoryLayout<UInt8>.size)
                precondition(result == 1)

                close(fd)
                return value
            #else
                return UInt8(arc4random_uniform(UInt32(UInt8.max) + 1))
            #endif
        })
    }
}
//
//  SecureBytes.swift
//  CryptoSwift
//
//  Copyright (C) 2014-2017 Krzyżanowski <marcin@krzyzanowskim.com>
//  This software is provided 'as-is', without any express or implied warranty.
//
//  In no event will the authors be held liable for any damages arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
//  - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
//  - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//  - This notice may not be removed or altered from any source or binary distribution.
//

#if os(Linux) || os(Android) || os(FreeBSD)
    import Glibc
#else
    import Darwin
#endif

///  Keeps bytes in memory. Because this is class, bytes are not copied
///  and memory area is locked as long as referenced, then unlocked on deinit
final class SecureBytes {
    fileprivate let bytes: Array<UInt8>
    let count: Int

    init(bytes: Array<UInt8>) {
        self.bytes = bytes
        self.count = bytes.count
        self.bytes.withUnsafeBufferPointer { (pointer) -> Void in
            mlock(pointer.baseAddress, pointer.count)
        }
    }

    deinit {
        self.bytes.withUnsafeBufferPointer { (pointer) -> Void in
            munlock(pointer.baseAddress, pointer.count)
        }
    }
}

extension SecureBytes: Collection {
    typealias Index = Int

    var endIndex: Int {
        return self.bytes.endIndex
    }

    var startIndex: Int {
        return self.bytes.startIndex
    }

    subscript(position: Index) -> UInt8 {
        return self.bytes[position]
    }

    subscript(bounds: Range<Index>) -> ArraySlice<UInt8> {
        return self.bytes[bounds]
    }

    func formIndex(after i: inout Int) {
        self.bytes.formIndex(after: &i)
    }

    func index(after i: Int) -> Int {
        return self.bytes.index(after: i)
    }
}

extension SecureBytes: ExpressibleByArrayLiteral {
    internal convenience init(arrayLiteral elements: UInt8...) {
        self.init(bytes: elements)
    }
}
//
//  SHA2.swift
//  CryptoSwift
//
//  Copyright (C) 2014-2017 Krzyżanowski <marcin@krzyzanowskim.com>
//  This software is provided 'as-is', without any express or implied warranty.
//
//  In no event will the authors be held liable for any damages arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
//  - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
//  - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//  - This notice may not be removed or altered from any source or binary distribution.
//

//  TODO: generic for process32/64 (UInt32/UInt64)
//

internal final class SHA2: DigestType {
    let variant: Variant
    let size: Int
    let blockSize: Int
    let digestLength: Int
    private let k: Array<UInt64>

    fileprivate var accumulated = Array<UInt8>()
    fileprivate var processedBytesTotalCount: Int = 0
    fileprivate var accumulatedHash32 = Array<UInt32>()
    fileprivate var accumulatedHash64 = Array<UInt64>()

    internal enum Variant: RawRepresentable {
        case sha256, sha512

        public var digestLength: Int {
            return self.rawValue / 8
        }

        public var blockSize: Int {
            switch self {
            case .sha256:
                return 64
            case .sha512:
                return 128
            }
        }

        public typealias RawValue = Int
        public var rawValue: RawValue {
            switch self {
            case .sha256:
                return 256
            case .sha512:
                return 512
            }
        }

        public init?(rawValue: RawValue) {
            switch (rawValue) {
            case 256:
                self = .sha256
                break
            case 512:
                self = .sha512
                break
            default:
                return nil
            }
        }

        fileprivate var h: Array<UInt64> {
            switch self {
            case .sha256:
                return [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]
            case .sha512:
                return [0x6a09e667f3bcc908, 0xbb67ae8584caa73b, 0x3c6ef372fe94f82b, 0xa54ff53a5f1d36f1, 0x510e527fade682d1, 0x9b05688c2b3e6c1f, 0x1f83d9abfb41bd6b, 0x5be0cd19137e2179]
            }
        }

        fileprivate var finalLength: Int {
            return Int.max
        }
    }

    internal init(variant: SHA2.Variant) {
        self.variant = variant
        switch self.variant {
        case .sha256:
            self.accumulatedHash32 = variant.h.map { UInt32($0) } // FIXME: UInt64 for process64
            self.blockSize = variant.blockSize
            self.size = variant.rawValue
            self.digestLength = variant.digestLength
            self.k = [0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
                      0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
                      0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
                      0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
                      0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
                      0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
                      0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
                      0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2]
        case .sha512:
            self.accumulatedHash64 = variant.h
            self.blockSize = variant.blockSize
            self.size = variant.rawValue
            self.digestLength = variant.digestLength
            self.k = [0x428a2f98d728ae22, 0x7137449123ef65cd, 0xb5c0fbcfec4d3b2f, 0xe9b5dba58189dbbc, 0x3956c25bf348b538,
                      0x59f111f1b605d019, 0x923f82a4af194f9b, 0xab1c5ed5da6d8118, 0xd807aa98a3030242, 0x12835b0145706fbe,
                      0x243185be4ee4b28c, 0x550c7dc3d5ffb4e2, 0x72be5d74f27b896f, 0x80deb1fe3b1696b1, 0x9bdc06a725c71235,
                      0xc19bf174cf692694, 0xe49b69c19ef14ad2, 0xefbe4786384f25e3, 0x0fc19dc68b8cd5b5, 0x240ca1cc77ac9c65,
                      0x2de92c6f592b0275, 0x4a7484aa6ea6e483, 0x5cb0a9dcbd41fbd4, 0x76f988da831153b5, 0x983e5152ee66dfab,
                      0xa831c66d2db43210, 0xb00327c898fb213f, 0xbf597fc7beef0ee4, 0xc6e00bf33da88fc2, 0xd5a79147930aa725,
                      0x06ca6351e003826f, 0x142929670a0e6e70, 0x27b70a8546d22ffc, 0x2e1b21385c26c926, 0x4d2c6dfc5ac42aed,
                      0x53380d139d95b3df, 0x650a73548baf63de, 0x766a0abb3c77b2a8, 0x81c2c92e47edaee6, 0x92722c851482353b,
                      0xa2bfe8a14cf10364, 0xa81a664bbc423001, 0xc24b8b70d0f89791, 0xc76c51a30654be30, 0xd192e819d6ef5218,
                      0xd69906245565a910, 0xf40e35855771202a, 0x106aa07032bbd1b8, 0x19a4c116b8d2d0c8, 0x1e376c085141ab53,
                      0x2748774cdf8eeb99, 0x34b0bcb5e19b48a8, 0x391c0cb3c5c95a63, 0x4ed8aa4ae3418acb, 0x5b9cca4f7763e373,
                      0x682e6ff3d6b2b8a3, 0x748f82ee5defb2fc, 0x78a5636f43172f60, 0x84c87814a1f0ab72, 0x8cc702081a6439ec,
                      0x90befffa23631e28, 0xa4506cebde82bde9, 0xbef9a3f7b2c67915, 0xc67178f2e372532b, 0xca273eceea26619c,
                      0xd186b8c721c0c207, 0xeada7dd6cde0eb1e, 0xf57d4f7fee6ed178, 0x06f067aa72176fba, 0x0a637dc5a2c898a6,
                      0x113f9804bef90dae, 0x1b710b35131c471b, 0x28db77f523047d84, 0x32caab7b40c72493, 0x3c9ebe0a15c9bebc,
                      0x431d67c49c100d4c, 0x4cc5d4becb3e42b6, 0x597f299cfc657e2a, 0x5fcb6fab3ad6faec, 0x6c44198c4a475817]
        }
    }

    internal func calculate(for bytes: Array<UInt8>) -> Array<UInt8> {
        do {
            return try self.update(withBytes: bytes, isLast: true)
        } catch {
            return []
        }
    }

    fileprivate func process64(block chunk: ArraySlice<UInt8>, currentHash hh: inout Array<UInt64>) {
        // break chunk into sixteen 64-bit words M[j], 0 ≤ j ≤ 15, big-endian
        // Extend the sixteen 64-bit words into eighty 64-bit words:
        var M = Array<UInt64>(repeating: 0, count: self.k.count)
        for x in 0 ..< M.count {
            switch (x) {
            case 0 ... 15:
                let start = chunk.startIndex.advanced(by: x * 8) // * MemoryLayout<UInt64>.size
                M[x] = UInt64(bytes: chunk, fromIndex: start)
                break
            default:
                let s0 = rotateRight(M[x - 15], by: 1) ^ rotateRight(M[x - 15], by: 8) ^ (M[x - 15] >> 7)
                let s1 = rotateRight(M[x - 2], by: 19) ^ rotateRight(M[x - 2], by: 61) ^ (M[x - 2] >> 6)
                M[x] = M[x - 16] &+ s0 &+ M[x - 7] &+ s1
                break
            }
        }

        var A = hh[0]
        var B = hh[1]
        var C = hh[2]
        var D = hh[3]
        var E = hh[4]
        var F = hh[5]
        var G = hh[6]
        var H = hh[7]

        // Main loop
        for j in 0 ..< self.k.count {
            let s0 = rotateRight(A, by: 28) ^ rotateRight(A, by: 34) ^ rotateRight(A, by: 39)
            let maj = (A & B) ^ (A & C) ^ (B & C)
            let t2 = s0 &+ maj
            let s1 = rotateRight(E, by: 14) ^ rotateRight(E, by: 18) ^ rotateRight(E, by: 41)
            let ch = (E & F) ^ ((~E) & G)
            let t1 = H &+ s1 &+ ch &+ self.k[j] &+ UInt64(M[j])

            H = G
            G = F
            F = E
            E = D &+ t1
            D = C
            C = B
            B = A
            A = t1 &+ t2
        }

        hh[0] = (hh[0] &+ A)
        hh[1] = (hh[1] &+ B)
        hh[2] = (hh[2] &+ C)
        hh[3] = (hh[3] &+ D)
        hh[4] = (hh[4] &+ E)
        hh[5] = (hh[5] &+ F)
        hh[6] = (hh[6] &+ G)
        hh[7] = (hh[7] &+ H)
    }

    // mutating currentHash in place is way faster than returning new result
    fileprivate func process32(block chunk: ArraySlice<UInt8>, currentHash hh: inout Array<UInt32>) {
        // break chunk into sixteen 32-bit words M[j], 0 ≤ j ≤ 15, big-endian
        // Extend the sixteen 32-bit words into sixty-four 32-bit words:
        var M = Array<UInt32>(repeating: 0, count: self.k.count)
        for x in 0 ..< M.count {
            switch (x) {
            case 0 ... 15:
                let start = chunk.startIndex.advanced(by: x * 4) // * MemoryLayout<UInt32>.size
                M[x] = UInt32(bytes: chunk, fromIndex: start)
                break
            default:
                let s0 = rotateRight(M[x - 15], by: 7) ^ rotateRight(M[x - 15], by: 18) ^ (M[x - 15] >> 3)
                let s1 = rotateRight(M[x - 2], by: 17) ^ rotateRight(M[x - 2], by: 19) ^ (M[x - 2] >> 10)
                M[x] = M[x - 16] &+ s0 &+ M[x - 7] &+ s1
                break
            }
        }

        var A = hh[0]
        var B = hh[1]
        var C = hh[2]
        var D = hh[3]
        var E = hh[4]
        var F = hh[5]
        var G = hh[6]
        var H = hh[7]

        // Main loop
        for j in 0 ..< self.k.count {
            let s0 = rotateRight(A, by: 2) ^ rotateRight(A, by: 13) ^ rotateRight(A, by: 22)
            let maj = (A & B) ^ (A & C) ^ (B & C)
            let t2 = s0 &+ maj
            let s1 = rotateRight(E, by: 6) ^ rotateRight(E, by: 11) ^ rotateRight(E, by: 25)
            let ch = (E & F) ^ ((~E) & G)
            let t1 = H &+ s1 &+ ch &+ UInt32(self.k[j]) &+ M[j]

            H = G
            G = F
            F = E
            E = D &+ t1
            D = C
            C = B
            B = A
            A = t1 &+ t2
        }

        hh[0] = hh[0] &+ A
        hh[1] = hh[1] &+ B
        hh[2] = hh[2] &+ C
        hh[3] = hh[3] &+ D
        hh[4] = hh[4] &+ E
        hh[5] = hh[5] &+ F
        hh[6] = hh[6] &+ G
        hh[7] = hh[7] &+ H
    }
}

extension SHA2: Updatable {

    internal func update<T: Collection>(withBytes bytes: T, isLast: Bool = false) throws -> Array<UInt8> where T.Iterator.Element == UInt8 {
        self.accumulated += bytes

        if isLast {
            let lengthInBits = (self.processedBytesTotalCount + self.accumulated.count) * 8
            let lengthBytes = lengthInBits.bytes(totalBytes: self.blockSize / 8) // A 64-bit/128-bit representation of b. blockSize fit by accident.

            // Step 1. Append padding
            bitPadding(to: &self.accumulated, blockSize: self.blockSize, allowance: self.blockSize / 8)

            // Step 2. Append Length a 64-bit representation of lengthInBits
            self.accumulated += lengthBytes
        }

        var processedBytes = 0
        for chunk in self.accumulated.batched(by: self.blockSize) {
            if (isLast || (self.accumulated.count - processedBytes) >= self.blockSize) {
                switch self.variant {
                case .sha256:
                    self.process32(block: chunk, currentHash: &self.accumulatedHash32)
                case .sha512:
                    self.process64(block: chunk, currentHash: &self.accumulatedHash64)
                }
                processedBytes += chunk.count
            }
        }
        self.accumulated.removeFirst(processedBytes)
        self.processedBytesTotalCount += processedBytes

        // output current hash
        var result = Array<UInt8>(repeating: 0, count: self.variant.digestLength)
        switch self.variant {
        case .sha256:
            var pos = 0
            for idx in 0 ..< self.accumulatedHash32.count where idx < self.variant.finalLength {
                let h = self.accumulatedHash32[idx].bigEndian
                result[pos] = UInt8(h & 0xff)
                result[pos + 1] = UInt8((h >> 8) & 0xff)
                result[pos + 2] = UInt8((h >> 16) & 0xff)
                result[pos + 3] = UInt8((h >> 24) & 0xff)
                pos += 4
            }
        case .sha512:
            var pos = 0
            for idx in 0 ..< self.accumulatedHash64.count where idx < self.variant.finalLength {
                let h = self.accumulatedHash64[idx].bigEndian
                result[pos] = UInt8(h & 0xff)
                result[pos + 1] = UInt8((h >> 8) & 0xff)
                result[pos + 2] = UInt8((h >> 16) & 0xff)
                result[pos + 3] = UInt8((h >> 24) & 0xff)
                result[pos + 4] = UInt8((h >> 32) & 0xff)
                result[pos + 5] = UInt8((h >> 40) & 0xff)
                result[pos + 6] = UInt8((h >> 48) & 0xff)
                result[pos + 7] = UInt8((h >> 56) & 0xff)
                pos += 8
            }
        }

        // reset hash value for instance
        if isLast {
            switch self.variant {
            case .sha256:
                self.accumulatedHash32 = variant.h.lazy.map { UInt32($0) } // FIXME: UInt64 for process64
            case .sha512:
                self.accumulatedHash64 = variant.h
            }
        }

        return result
    }
}
//
//  StringExtension.swift
//  CryptoSwift
//
//  Copyright (C) 2014-2017 Krzyżanowski <marcin@krzyzanowskim.com>
//  This software is provided 'as-is', without any express or implied warranty.
//
//  In no event will the authors be held liable for any damages arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
//  - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
//  - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//  - This notice may not be removed or altered from any source or binary distribution.
//

/** String extension */
extension String {

    internal func sha256() -> String {
        return self.utf8.lazy.map({ $0 as UInt8 }).sha256().toHexString()
    }

    internal func sha512() -> String {
        return self.utf8.lazy.map({ $0 as UInt8 }).sha512().toHexString()
    }

    /// - parameter authenticator: Instance of `Authenticator`
    /// - returns: hex string of string
    internal func authenticate<A: Authenticator>(with authenticator: A) throws -> String {
        return try Array(self.utf8).authenticate(with: authenticator).toHexString()
    }

}
//
//  ByteExtension.swift
//  CryptoSwift
//
//  Copyright (C) 2014-2017 Krzyżanowski <marcin@krzyzanowskim.com>
//  This software is provided 'as-is', without any express or implied warranty.
//
//  In no event will the authors be held liable for any damages arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
//  - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
//  - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//  - This notice may not be removed or altered from any source or binary distribution.
//

#if os(Linux) || os(Android) || os(FreeBSD)
    import Glibc
#else
    import Darwin
#endif

public protocol _UInt8Type {}
extension UInt8: _UInt8Type {}

/** casting */
extension UInt8 {

    /** cast because UInt8(<UInt32>) because std initializer crash if value is > byte */
    static func with(value: UInt64) -> UInt8 {
        let tmp = value & 0xFF
        return UInt8(tmp)
    }

    static func with(value: UInt32) -> UInt8 {
        let tmp = value & 0xFF
        return UInt8(tmp)
    }

    static func with(value: UInt16) -> UInt8 {
        let tmp = value & 0xFF
        return UInt8(tmp)
    }
}

/** Bits */
extension UInt8 {

    init(bits: [Bit]) {
        self.init(integerFrom(bits) as UInt8)
    }

    /** array of bits */
    internal func bits() -> [Bit] {
        let totalBitsCount = MemoryLayout<UInt8>.size * 8

        var bitsArray = [Bit](repeating: Bit.zero, count: totalBitsCount)

        for j in 0 ..< totalBitsCount {
            let bitVal: UInt8 = 1 << UInt8(totalBitsCount - 1 - j)
            let check = self & bitVal

            if (check != 0) {
                bitsArray[j] = Bit.one
            }
        }
        return bitsArray
    }

    internal func bits() -> String {
        var s = String()
        let arr: [Bit] = self.bits()
        for idx in arr.indices {
            s += (arr[idx] == Bit.one ? "1" : "0")
            if (idx.advanced(by: 1) % 8 == 0) { s += " " }
        }
        return s
    }
}
//
//  UInt16+Extension.swift
//  CryptoSwift
//
//  Copyright (C) 2014-2017 Krzyżanowski <marcin@krzyzanowskim.com>
//  This software is provided 'as-is', without any express or implied warranty.
//
//  In no event will the authors be held liable for any damages arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
//  - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
//  - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//  - This notice may not be removed or altered from any source or binary distribution.
//

/** array of bytes */
extension UInt16 {

    @_specialize(where T == ArraySlice<UInt8>)
    init<T: Collection>(bytes: T) where T.Iterator.Element == UInt8, T.Index == Int {
        self = UInt16(bytes: bytes, fromIndex: bytes.startIndex)
    }

    @_specialize(where T == ArraySlice<UInt8>)
    init<T: Collection>(bytes: T, fromIndex index: T.Index) where T.Iterator.Element == UInt8, T.Index == Int {
        let val0 = UInt16(bytes[index.advanced(by: 0)]) << 8
        let val1 = UInt16(bytes[index.advanced(by: 1)])

        self = val0 | val1
    }

    func bytes(totalBytes: Int = MemoryLayout<UInt16>.size) -> Array<UInt8> {
        return arrayOfBytes(value: self, length: totalBytes)
    }
}
//
//  UInt32Extension.swift
//  CryptoSwift
//
//  Copyright (C) 2014-2017 Krzyżanowski <marcin@krzyzanowskim.com>
//  This software is provided 'as-is', without any express or implied warranty.
//
//  In no event will the authors be held liable for any damages arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
//  - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
//  - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//  - This notice may not be removed or altered from any source or binary distribution.
//

#if os(Linux) || os(Android) || os(FreeBSD)
    import Glibc
#else
    import Darwin
#endif

protocol _UInt32Type {}
extension UInt32: _UInt32Type {}

/** array of bytes */
extension UInt32 {

    @_specialize(where T == ArraySlice<UInt8>)
    init<T: Collection>(bytes: T) where T.Iterator.Element == UInt8, T.Index == Int {
        self = UInt32(bytes: bytes, fromIndex: bytes.startIndex)
    }

    @_specialize(where T == ArraySlice<UInt8>)
    init<T: Collection>(bytes: T, fromIndex index: T.Index) where T.Iterator.Element == UInt8, T.Index == Int {
        let val0 = UInt32(bytes[index.advanced(by: 0)]) << 24
        let val1 = UInt32(bytes[index.advanced(by: 1)]) << 16
        let val2 = UInt32(bytes[index.advanced(by: 2)]) << 8
        let val3 = UInt32(bytes[index.advanced(by: 3)])

        self = val0 | val1 | val2 | val3
    }

    func bytes(totalBytes: Int = MemoryLayout<UInt32>.size) -> Array<UInt8> {
        return arrayOfBytes(value: self, length: totalBytes)
    }
}
//
//  UInt64Extension.swift
//  CryptoSwift
//
//  Copyright (C) 2014-2017 Krzyżanowski <marcin@krzyzanowskim.com>
//  This software is provided 'as-is', without any express or implied warranty.
//
//  In no event will the authors be held liable for any damages arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
//  - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
//  - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//  - This notice may not be removed or altered from any source or binary distribution.
//

/** array of bytes */
extension UInt64 {

//    init<T: Collection>(bytes: T) where T.Iterator.Element == UInt8, T.Index == Int {
//        self = 0
//    }

    @_specialize(where T == ArraySlice<UInt8>)
    init<T: Collection>(bytes: T) where T.Iterator.Element == UInt8, T.IndexDistance == Int, T.Index == Int {
        self = UInt64(bytes: bytes, fromIndex: bytes.startIndex)
    }

    @_specialize(where T == ArraySlice<UInt8>)
    init<T: Collection>(bytes: T, fromIndex index: T.Index) where T.Iterator.Element == UInt8, T.IndexDistance == Int, T.Index == Int {
        let val0 = UInt64(bytes[index.advanced(by: 0)]) << 56
        let val1 = UInt64(bytes[index.advanced(by: 1)]) << 48
        let val2 = UInt64(bytes[index.advanced(by: 2)]) << 40
        let val3 = UInt64(bytes[index.advanced(by: 3)]) << 32
        let val4 = UInt64(bytes[index.advanced(by: 4)]) << 24
        let val5 = UInt64(bytes[index.advanced(by: 5)]) << 16
        let val6 = UInt64(bytes[index.advanced(by: 6)]) << 8
        let val7 = UInt64(bytes[index.advanced(by: 7)])

        self = val0 | val1 | val2 | val3 | val4 | val5 | val6 | val7
    }

    func bytes(totalBytes: Int = MemoryLayout<UInt64>.size) -> Array<UInt8> {
        return arrayOfBytes(value: self, length: totalBytes)
    }
}
//
//  Updatable.swift
//  CryptoSwift
//
//  Copyright (C) 2014-2017 Krzyżanowski <marcin@krzyzanowskim.com>
//  This software is provided 'as-is', without any express or implied warranty.
//
//  In no event will the authors be held liable for any damages arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
//  - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
//  - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//  - This notice may not be removed or altered from any source or binary distribution.
//

/// A type that supports incremental updates. For example Digest or Cipher may be updatable
/// and calculate result incerementally.
internal protocol Updatable {
    /// Update given bytes in chunks.
    ///
    /// - parameter bytes: Bytes to process.
    /// - parameter isLast: Indicate if given chunk is the last one. No more updates after this call.
    /// - returns: Processed data or empty array.
    mutating func update<T: Collection>(withBytes bytes: T, isLast: Bool) throws -> Array<UInt8> where T.Iterator.Element == UInt8

    /// Update given bytes in chunks.
    ///
    /// - Parameters:
    ///   - bytes: Bytes to process.
    ///   - isLast: Indicate if given chunk is the last one. No more updates after this call.
    ///   - output: Resulting bytes callback.
    /// - Returns: Processed data or empty array.
    mutating func update<T: Collection>(withBytes bytes: T, isLast: Bool, output: (_ bytes: Array<UInt8>) -> Void) throws where T.Iterator.Element == UInt8

    /// Finish updates. This may apply padding.
    /// - parameter bytes: Bytes to process
    /// - returns: Processed data.
    mutating func finish<T: Collection>(withBytes bytes: T) throws -> Array<UInt8> where T.Iterator.Element == UInt8

    /// Finish updates. This may apply padding.
    /// - parameter bytes: Bytes to process
    /// - parameter output: Resulting data
    /// - returns: Processed data.
    mutating func finish<T: Collection>(withBytes bytes: T, output: (_ bytes: Array<UInt8>) -> Void) throws where T.Iterator.Element == UInt8
}

extension Updatable {

    mutating internal func update<T: Collection>(withBytes bytes: T, isLast: Bool = false, output: (_ bytes: Array<UInt8>) -> Void) throws where T.Iterator.Element == UInt8 {
        let processed = try self.update(withBytes: bytes, isLast: isLast)
        if (!processed.isEmpty) {
            output(processed)
        }
    }

    mutating internal func finish<T: Collection>(withBytes bytes: T) throws -> Array<UInt8> where T.Iterator.Element == UInt8 {
        return try self.update(withBytes: bytes, isLast: true)
    }

    mutating internal func finish() throws -> Array<UInt8> {
        return try self.update(withBytes: [], isLast: true)
    }

    mutating internal func finish<T: Collection>(withBytes bytes: T, output: (_ bytes: Array<UInt8>) -> Void) throws where T.Iterator.Element == UInt8 {
        let processed = try self.update(withBytes: bytes, isLast: true)
        if (!processed.isEmpty) {
            output(processed)
        }
    }

    mutating internal func finish(output: (Array<UInt8>) -> Void) throws {
        try self.finish(withBytes: [], output: output)
    }
}
//
//  Utils.swift
//  CryptoSwift
//
//  Copyright (C) 2014-2017 Krzyżanowski <marcin@krzyzanowskim.com>
//  This software is provided 'as-is', without any express or implied warranty.
//
//  In no event will the authors be held liable for any damages arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
//  - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
//  - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//  - This notice may not be removed or altered from any source or binary distribution.
//

func rotateLeft(_ value: UInt8, by: UInt8) -> UInt8 {
    return ((value << by) & 0xFF) | (value >> (8 - by))
}

func rotateLeft(_ value: UInt16, by: UInt16) -> UInt16 {
    return ((value << by) & 0xFFFF) | (value >> (16 - by))
}

func rotateLeft(_ value: UInt32, by: UInt32) -> UInt32 {
    return ((value << by) & 0xFFFFFFFF) | (value >> (32 - by))
}

func rotateLeft(_ value: UInt64, by: UInt64) -> UInt64 {
    return (value << by) | (value >> (64 - by))
}

func rotateRight(_ value: UInt16, by: UInt16) -> UInt16 {
    return (value >> by) | (value << (16 - by))
}

func rotateRight(_ value: UInt32, by: UInt32) -> UInt32 {
    return (value >> by) | (value << (32 - by))
}

func rotateRight(_ value: UInt64, by: UInt64) -> UInt64 {
    return ((value >> by) | (value << (64 - by)))
}

func reversed(_ uint8: UInt8) -> UInt8 {
    var v = uint8
    v = (v & 0xF0) >> 4 | (v & 0x0F) << 4
    v = (v & 0xCC) >> 2 | (v & 0x33) << 2
    v = (v & 0xAA) >> 1 | (v & 0x55) << 1
    return v
}

func reversed(_ uint32: UInt32) -> UInt32 {
    var v = uint32
    v = ((v >> 1) & 0x55555555) | ((v & 0x55555555) << 1)
    v = ((v >> 2) & 0x33333333) | ((v & 0x33333333) << 2)
    v = ((v >> 4) & 0x0f0f0f0f) | ((v & 0x0f0f0f0f) << 4)
    v = ((v >> 8) & 0x00ff00ff) | ((v & 0x00ff00ff) << 8)
    v = ((v >> 16) & 0xffff) | ((v & 0xffff) << 16)
    return v
}

func xor(_ a: Array<UInt8>, _ b: Array<UInt8>) -> Array<UInt8> {
    return xor(a.suffix(from: a.startIndex), b.suffix(from: b.startIndex))
}

func xor(_ a: Array<UInt8>, _ b: ArraySlice<UInt8>) -> Array<UInt8> {
    return xor(a.suffix(from: a.startIndex), b.suffix(from: b.startIndex))
}

func xor(_ a: ArraySlice<UInt8>, _ b: Array<UInt8>) -> Array<UInt8> {
    return xor(a.suffix(from: a.startIndex), b.suffix(from: b.startIndex))
}

func xor(_ a: ArraySlice<UInt8>, _ b: ArraySlice<UInt8>) -> Array<UInt8> {
    var xored = Array<UInt8>(repeating: 0, count: min(a.count, b.count))
    for i in 0 ..< xored.count {
        xored[xored.startIndex.advanced(by: i)] = a[a.startIndex.advanced(by: i)] ^ b[b.startIndex.advanced(by: i)]
    }
    return xored
}


/**
 ISO/IEC 9797-1 Padding method 2.
 Add a single bit with value 1 to the end of the data.
 If necessary add bits with value 0 to the end of the data until the padded data is a multiple of blockSize.
 - parameters:
 - blockSize: Padding size in bytes.
 - allowance: Excluded trailing number of bytes.
 */
@inline(__always)
func bitPadding(to data: inout Array<UInt8>, blockSize: Int, allowance: Int = 0) {
    let msgLength = data.count
    // Step 1. Append Padding Bits
    // append one bit (UInt8 with one bit) to message
    data.append(0x80)

    // Step 2. append "0" bit until message length in bits ≡ 448 (mod 512)
    let max = blockSize - allowance // 448, 986
    if msgLength % blockSize < max { // 448
        data += Array<UInt8>(repeating: 0, count: max - 1 - (msgLength % blockSize))
    } else {
        data += Array<UInt8>(repeating: 0, count: blockSize + max - 1 - (msgLength % blockSize))
    }
}
//
//  ZeroPadding.swift
//  CryptoSwift
//
//  Copyright (C) 2014-2017 Krzyżanowski <marcin@krzyzanowskim.com>
//  This software is provided 'as-is', without any express or implied warranty.
//
//  In no event will the authors be held liable for any damages arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
//  - The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation is required.
//  - Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//  - This notice may not be removed or altered from any source or binary distribution.
//

/// All the bytes that are required to be padded are padded with zero.
/// Zero padding may not be reversible if the original file ends with one or more zero bytes.
internal struct ZeroPadding: Padding {

    internal init() {
    }

    internal func add(to bytes: Array<UInt8>, blockSize: Int) -> Array<UInt8> {
        let paddingCount = blockSize - (bytes.count % blockSize)
        if paddingCount > 0 {
            return bytes + Array<UInt8>(repeating: 0, count: paddingCount)
        }
        return bytes
    }

    internal func remove(from bytes: Array<UInt8>, blockSize: Int?) -> Array<UInt8> {
        for (idx, value) in bytes.reversed().enumerated() {
            if value != 0 {
                return Array(bytes[0 ..< bytes.count - idx])
            }
        }
        return bytes
    }
}
