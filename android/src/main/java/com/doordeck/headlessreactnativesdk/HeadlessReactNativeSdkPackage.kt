package com.doordeck.headlessreactnativesdk

import com.doordeck.multiplatform.sdk.ApplicationContext
import com.doordeck.multiplatform.sdk.KDoordeckFactory
import com.doordeck.multiplatform.sdk.config.SdkConfig
import com.facebook.react.BaseReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.model.ReactModuleInfo
import com.facebook.react.module.model.ReactModuleInfoProvider
import java.util.HashMap

class HeadlessReactNativeSdkPackage : BaseReactPackage() {
  override fun getModule(name: String, reactContext: ReactApplicationContext): NativeModule? {
    return if (name == HeadlessReactNativeSdkModule.NAME) {
      // The Android application context is registered directly (the Builder's
      // setApplicationContext helper was removed); initialize() is synchronous.
      ApplicationContext.set(reactContext.applicationContext)
      HeadlessReactNativeSdkModule(
        reactContext = reactContext,
        doordeckSdk = KDoordeckFactory.initialize(SdkConfig.Builder().build())
      )
    } else {
      null
    }
  }

  override fun getReactModuleInfoProvider(): ReactModuleInfoProvider {
    return ReactModuleInfoProvider {
      val moduleInfos: MutableMap<String, ReactModuleInfo> = HashMap()
      moduleInfos[HeadlessReactNativeSdkModule.NAME] = ReactModuleInfo(
        HeadlessReactNativeSdkModule.NAME,
        HeadlessReactNativeSdkModule.NAME,
        false,  // canOverrideExistingModule
        false,  // needsEagerInit
        false,  // isCxxModule
        true // isTurboModule
      )
      moduleInfos
    }
  }
}
