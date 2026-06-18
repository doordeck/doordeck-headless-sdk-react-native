//
//  HeadlessReactNativeSdkImpl.swift
//  HeadlessReactNativeSdkImpl
//
//  Created by Rafael Ruiz Muñoz on 10/02/2025.
//

import Foundation
import React
import DoordeckSDK

@objc(HeadlessReactNativeSdkImpl)
public class HeadlessReactNativeSdkImpl: NSObject {

  // The Doordeck SDK is now initialized through an async/throwing factory, which
  // cannot run in `init()`. Initialize it lazily on first use and cache it.
  private var doordeckSdk: Doordeck?

  private func sdk() async throws -> Doordeck {
    if let existing = doordeckSdk {
      return existing
    }
    guard let initialized = try await KDoordeckFactory().initialize(sdkConfig: SdkConfig.Builder().build()) else {
      throw HeadlessReactNativeSdkImpl.makeError("Failed to initialize the Doordeck SDK")
    }
    doordeckSdk = initialized
    return initialized
  }

  /**
   * ✅ Authentication Methods
   */

  @objc public func login(
    _ email: String,
    password: String,
    resolver: @escaping RCTPromiseResolveBlock,
    rejecter: @escaping RCTPromiseRejectBlock
  ) {
    Task {
      do {
        let sdk = try await self.sdk()
        self.setKeyPairIfNeeded(sdk)
        _ = try await sdk.accountless().login(email: email, password: password)
        try await self.respondNeedsVerification(sdk, resolver)
      } catch {
        rejecter("LOGIN_ERROR", error.localizedDescription, error)
      }
    }
  }

  @objc public func setAuthToken(
    _ authToken: String,
    resolver: @escaping RCTPromiseResolveBlock,
    rejecter: @escaping RCTPromiseRejectBlock
  ) {
    Task {
      do {
        let sdk = try await self.sdk()
        self.setKeyPairIfNeeded(sdk)
        sdk.contextManager().setCloudAuthToken(token: authToken)
        try await self.respondNeedsVerification(sdk, resolver)
      } catch {
        rejecter("SET_AUTH_TOKEN_ERROR", error.localizedDescription, error)
      }
    }
  }

  @objc public func verify(
    _ code: String,
    resolver: @escaping RCTPromiseResolveBlock,
    rejecter: @escaping RCTPromiseRejectBlock
  ) {
    Task {
      do {
        let sdk = try await self.sdk()
        _ = try await sdk.account().verifyEphemeralKeyRegistration(code: code, publicKey: nil, privateKey: nil)
        resolver(nil)
      } catch {
        rejecter("VERIFY_ERROR", error.localizedDescription, error)
      }
    }
  }

  @objc public func logout(
    _ resolver: @escaping RCTPromiseResolveBlock,
    rejecter: @escaping RCTPromiseRejectBlock
  ) {
    Task {
      do {
        let sdk = try await self.sdk()
        try await sdk.account().logout()
        resolver(nil)
      } catch {
        rejecter("LOGOUT_ERROR", error.localizedDescription, error)
      }
    }
  }

  /**
   * ✅ User Operations
   */

  @objc public func getUserDetails(
    _ resolver: @escaping RCTPromiseResolveBlock,
    rejecter: @escaping RCTPromiseRejectBlock
  ) {
    Task {
      do {
        let sdk = try await self.sdk()
        guard let response = try await sdk.account().getUserDetails() else {
          throw HeadlessReactNativeSdkImpl.makeError("Unknown error occurred")
        }
        let contextManager = sdk.contextManager()
        let tokenAboutToExpire = try await contextManager.isCloudAuthTokenInvalidOrExpired(checkServerInvalidation: false)
        resolver(response.toNativeMap(
          userId: contextManager.getUserId()?.uuidString,
          certificateChainAboutToExpire: contextManager.isCertificateChainInvalidOrExpired(),
          tokenAboutToExpire: tokenAboutToExpire?.boolValue ?? false
        ))
      } catch {
        rejecter("USER_DETAILS_ERROR", error.localizedDescription, error)
      }
    }
  }

  /**
   * ✅ Device and Tile Operations
   */

  @objc public func getLocksBelongingToTile(
    _ tileId: String,
    resolver: @escaping RCTPromiseResolveBlock,
    rejecter: @escaping RCTPromiseRejectBlock
  ) {
    Task {
      do {
        guard let tileUuid = UUID(uuidString: tileId) else {
          throw HeadlessReactNativeSdkImpl.makeError("Invalid tileId: \(tileId)")
        }
        let sdk = try await self.sdk()
        guard let response = try await sdk.tiles().getLocksBelongingToTile(tileId: tileUuid) else {
          throw HeadlessReactNativeSdkImpl.makeError("Unknown error occurred")
        }
        resolver(response.toNativeMap())
      } catch {
        rejecter("LOCKS_ERROR", error.localizedDescription, error)
      }
    }
  }

  @objc public func unlockDevice(
    _ lockId: String,
    resolver: @escaping RCTPromiseResolveBlock,
    rejecter: @escaping RCTPromiseRejectBlock
  ) {
    Task {
      do {
        guard let lockUuid = UUID(uuidString: lockId) else {
          throw HeadlessReactNativeSdkImpl.makeError("Invalid lockId: \(lockId)")
        }
        let sdk = try await self.sdk()

        let now = Date()
        let baseOperation = LockOperations.BaseOperation(
          userId: nil,
          userCertificateChain: nil,
          userPrivateKey: nil,
          lockId: lockUuid,
          notBefore: now,
          issuedAt: now,
          expiresAt: now.addingTimeInterval(60),
          jti: UUID()
        )

        let unlockOperation = LockOperations.UnlockOperation(baseOperation: baseOperation, directAccessEndpoints: nil)

        try await sdk.lockOperations().unlock(unlockOperation: unlockOperation)
        resolver(nil)
      } catch {
        rejecter("UNLOCK_ERROR", error.localizedDescription, error)
      }
    }
  }

  private func setKeyPairIfNeeded(_ sdk: Doordeck) {
    if (!sdk.contextManager().isKeyPairValid()) {
      let newKeyPair = sdk.crypto().generateKeyPair()
      sdk.contextManager().setKeyPair(publicKey: newKeyPair.public_, privateKey: newKeyPair.private_)
    }
  }

  private func respondNeedsVerification(
    _ sdk: Doordeck,
    _ resolver: @escaping RCTPromiseResolveBlock
  ) async throws {
    guard let response = try await sdk.helper().assistedRegisterEphemeralKey(publicKey: nil, privateKey: nil) else {
      throw HeadlessReactNativeSdkImpl.makeError("Unknown error occurred")
    }
    resolver(response.toNativeMap())
  }

  private static func makeError(_ message: String) -> NSError {
    return NSError(
      domain: "HeadlessReactNativeSdk",
      code: -1,
      userInfo: [NSLocalizedDescriptionKey: message]
    )
  }
}

/**
 * ✅ Extensions for converting Doordeck responses into NSDictionary (React Native format)
 */

extension AssistedRegisterEphemeralKeyResponse {
  func toNativeMap() -> NSDictionary {
    return ["requiresVerification": requiresVerification]
  }
}

extension TileLocksResponse {
  func toNativeMap() -> NSDictionary {
    return [
      "siteId": siteId.uuidString,
      "tileId": tileId.uuidString,
      "deviceIds": deviceIds.map { $0.uuidString }
    ]
  }
}

extension UserDetailsResponse {
  func toNativeMap(userId: String?, certificateChainAboutToExpire: Bool, tokenAboutToExpire: Bool) -> NSDictionary {
    return [
      "userId": userId as Any,
      "certificateChainAboutToExpire": certificateChainAboutToExpire,
      "tokenAboutToExpire": tokenAboutToExpire,
      "publicKey": publicKey,
      "email": email,
      "displayName": displayName as Any,
      "emailVerified": emailVerified
    ]
  }
}
