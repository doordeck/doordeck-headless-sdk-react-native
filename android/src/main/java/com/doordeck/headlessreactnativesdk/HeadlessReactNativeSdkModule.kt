package com.doordeck.headlessreactnativesdk

import com.doordeck.multiplatform.sdk.Doordeck
import com.doordeck.multiplatform.sdk.model.data.LockOperations
import com.doordeck.multiplatform.sdk.model.responses.AssistedRegisterEphemeralKeyResponse
import com.doordeck.multiplatform.sdk.model.responses.TileLocksResponse
import com.doordeck.multiplatform.sdk.model.responses.UserDetailsResponse
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.annotations.ReactModule
import java.util.Base64
import java.util.UUID

@ReactModule(name = HeadlessReactNativeSdkModule.NAME)
class HeadlessReactNativeSdkModule(
  reactContext: ReactApplicationContext,
  private val doordeckSdk: Doordeck,
) : NativeHeadlessReactNativeSdkSpec(reactContext) {

  override fun getName(): String {
    return NAME
  }

  /**
   * Auth operations
   */

  override fun login(
    email: String,
    password: String,
    promise: Promise,
  ) {
    setKeyPairIfNeeded()

    doordeckSdk.accountless().loginAsync(email, password)
      .thenApply {
        respondNeedsVerification(promise)
      }
      .exceptionally { error ->
        promise.reject("LOGIN_ERROR", error)
      }
  }

  override fun setAuthToken(
    authToken: String,
    promise: Promise,
  ) {
    setKeyPairIfNeeded()

    doordeckSdk.contextManager().setCloudAuthToken(authToken)
    respondNeedsVerification(promise)
  }

  override fun verify(code: String, promise: Promise) {
    doordeckSdk.account().verifyEphemeralKeyRegistrationAsync(code)
      .thenApply {
        promise.resolve(null)
      }
      .exceptionally { error ->
        promise.reject("VERIFY_ERROR", error)
      }
  }

  override fun logout(promise: Promise) {
    doordeckSdk.account().logoutAsync()
      .thenApply {
        promise.resolve(null)
      }
      .exceptionally { error ->
        promise.reject("LOGOUT_ERROR", error)
      }
  }

  /**
   * User operations
   */
  override fun getUserDetails(promise: Promise) {
    val contextManager = doordeckSdk.contextManager()

    doordeckSdk.account().getUserDetailsAsync()
      .thenCompose { response ->
        // The cloud-auth-token expiry check is now asynchronous; chain it and
        // build the response once it resolves.
        contextManager.isCloudAuthTokenInvalidOrExpiredAsync(false)
          .thenApply { tokenAboutToExpire ->
            promise.resolve(response.toNativeMap(
              userId = contextManager.getUserId()?.toString(),
              certificateChainAboutToExpire = contextManager.isCertificateChainInvalidOrExpired(),
              tokenAboutToExpire = tokenAboutToExpire,
            ))
          }
      }
      .exceptionally { error ->
        promise.reject("USER_DETAILS_ERROR", error)
      }
  }

  /**
   * Device and tile operations
   */

  override fun getLocksBelongingToTile(tileId: String, promise: Promise) {
    doordeckSdk.tiles().getLocksBelongingToTileAsync(UUID.fromString(tileId))
      .thenApply { response ->
        promise.resolve(response.toNativeMap())
      }
      .exceptionally { error ->
        promise.reject("LOCKS_ERROR", error)
      }
  }

  override fun unlockDevice(lockId: String, promise: Promise) {
    doordeckSdk.lockOperations().unlockAsync(
      LockOperations.UnlockOperation(
        LockOperations.BaseOperation(
          lockId = UUID.fromString(lockId),
        )
      )
    )
      .thenApply {
        promise.resolve(null)
      }
      .exceptionally { error ->
        promise.reject("UNLOCK_ERROR", error)
      }
  }


  companion object {
    const val NAME = "HeadlessReactNativeSdk"
  }

  private fun setKeyPairIfNeeded() {
    if (!doordeckSdk.contextManager().isKeyPairValid()) {
      val newKeyPair = doordeckSdk.crypto().generateKeyPair()
      doordeckSdk.contextManager().setKeyPair(newKeyPair)
    }
  }

  private fun respondNeedsVerification(promise: Promise) {
    doordeckSdk.helper().assistedRegisterEphemeralKeyAsync()
      .thenApply { response ->
        promise.resolve(response.toNativeMap())
      }
      .exceptionally { error ->
        promise.reject("NEEDS_VERIFICATION_ERROR", error)
      }
  }

  private fun AssistedRegisterEphemeralKeyResponse.toNativeMap() = Arguments.createMap().apply {
    putBoolean("requiresVerification", requiresVerification)
  }

  private fun TileLocksResponse.toNativeMap() = Arguments.createMap().apply {
    putString("siteId", siteId.toString())
    putString("tileId", tileId.toString())
    putArray("deviceIds", Arguments.createArray().apply {
      deviceIds.forEach { pushString(it.toString()) }
    })
  }

  private fun UserDetailsResponse.toNativeMap(
    userId: String?,
    certificateChainAboutToExpire: Boolean,
    tokenAboutToExpire: Boolean,
  ) = Arguments.createMap().apply {
    putString("userId", userId)
    putBoolean("certificateChainAboutToExpire", certificateChainAboutToExpire)
    putBoolean("tokenAboutToExpire", tokenAboutToExpire)
    // The SDK now returns a java.security.PublicKey; expose its X.509 (SPKI)
    // form as a base64 string to preserve the `publicKey: string` JS contract.
    putString("publicKey", Base64.getEncoder().encodeToString(publicKey.encoded))
    putString("email", email)
    putString("displayName", displayName)
    putBoolean("emailVerified", emailVerified)
  }
}
