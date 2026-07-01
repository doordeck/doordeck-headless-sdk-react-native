require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "HeadlessReactNativeSdk"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => min_ios_version_supported }
  s.source       = { :git => "https://github.com/doordeck/doordeck-headless-sdk-react-native.git", :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm,cpp,swift}"
  s.private_header_files = "ios/**/*.h"
  s.preserve_paths = "ios/**/*.{h,m,mm,swift}"

  # The native Doordeck SDK is distributed as a Swift Package (a binary xcframework),
  # not as a CocoaPods pod. Wire it in via React Native's built-in SPM support
  # (spm_dependency, available on RN >= 0.76). The SPM product/module is "DoordeckSDK",
  # so `import DoordeckSDK` in the Swift bridge continues to work unchanged.
  spm_dependency(s,
    url: 'https://github.com/doordeck/doordeck-headless-sdk-spm.git',
    requirement: { kind: 'exactVersion', version: '1.128.0' },
    products: ['DoordeckSDK']
  )

  # Install all React Native dependencies (React-Core, RCT-Folly, RCTRequired,
  # RCTTypeSafety, ReactCommon, codegen, New Architecture flags, etc.) via the
  # official helper. This resolves the correct spec sources for the installed RN
  # version — replacing the hand-maintained dependency list, which broke on RN
  # 0.86 (`Unable to find a specification for RCT-Folly`).
  install_modules_dependencies(s)
end
