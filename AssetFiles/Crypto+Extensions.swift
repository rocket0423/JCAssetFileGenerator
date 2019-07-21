//
//  Crypto+Extensions.swift
//  DDEvent
//
//  Created by Justin Carstens on 2/3/19.
//  Copyright © 2019 DoubleDutch. All rights reserved.
//

import Foundation
import CommonCrypto

/**
 This was coppied from a stack overflow answer here https://stackoverflow.com/a/52120827
*/

public enum HashOutputType {
  case hex
  case base64
}

public enum HashType {
  case md5
  case sha1
  case sha224
  case sha256
  case sha384
  case sha512

  var length: Int32 {
    switch self {
    case .md5: return CC_MD5_DIGEST_LENGTH
    case .sha1: return CC_SHA1_DIGEST_LENGTH
    case .sha224: return CC_SHA224_DIGEST_LENGTH
    case .sha256: return CC_SHA256_DIGEST_LENGTH
    case .sha384: return CC_SHA384_DIGEST_LENGTH
    case .sha512: return CC_SHA512_DIGEST_LENGTH
    }
  }
}

public extension String {

  /**
   Hashing algorithm for hashing a string instance.

   - parameter type:   The type of hash to use.
   - parameter output: The type of output desired, defaults to .hex.

   - returns: The requested hash output or nil if failure.
   */
  func hashed(_ type: HashType, output: HashOutputType = .hex) -> String? {
    return data(using: .utf8)?.hashed(type, output: output)
  }

}

extension Data {

  /**
   Hashing algorithm that prepends an RSA2048ASN1Header to the beginning of the data being hashed.

   - parameter type:   The type of hash algorithm to use for the hashing operation.
   - parameter output: The type of output string desired.

   - returns: A hash string using the specified hashing algorithm, or nil.
   */
  public func hashWithRSA2048Asn1Header(_ type: HashType, output: HashOutputType = .hex) -> String? {
    let rsa2048Asn1Header:[UInt8] = [
      0x30, 0x82, 0x01, 0x22, 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86,
      0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x82, 0x01, 0x0f, 0x00
    ]

    var headerData = Data(rsa2048Asn1Header)
    headerData.append(self)

    return hashed(type, output: output)
  }

  /**
   Hashing algorithm for hashing a Data instance.

   - parameter type:   The type of hash to use.
   - parameter output: The type of hash output desired, defaults to .hex.

   - returns: The requested hash output or nil if failure.
   */
  public func hashed(_ type: HashType, output: HashOutputType = .hex) -> String? {
    // setup data variable to hold hashed value
    var digest = Data(count: Int(type.length))

    _ = digest.withUnsafeMutableBytes{ digestBytes -> UInt8 in
      self.withUnsafeBytes { messageBytes -> UInt8 in
        if let mb = messageBytes.baseAddress, let db = digestBytes.bindMemory(to: UInt8.self).baseAddress {
          let length = CC_LONG(self.count)
          switch type {
          case .md5: CC_MD5(mb, length, db)
          case .sha1: CC_SHA1(mb, length, db)
          case .sha224: CC_SHA224(mb, length, db)
          case .sha256: CC_SHA256(mb, length, db)
          case .sha384: CC_SHA384(mb, length, db)
          case .sha512: CC_SHA512(mb, length, db)
          }
        }
        return 0
      }
    }

    // return the value based on the specified output type.
    switch output {
    case .hex: return digest.map { String(format: "%02hhx", $0) }.joined()
    case .base64: return digest.base64EncodedString()
    }
  }

}
