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

  # The native Doordeck SDK (a binary xcframework) is consumed as a CocoaPods
  # dependency rather than via RN's spm_dependency. CocoaPods both LINKS and
  # EMBEDS vendored dynamic frameworks in every linkage mode (static libraries,
  # `use_frameworks! :linkage => :static` and `:dynamic`), whereas spm_dependency
  # only links — consumers crashed at launch with "dyld: Library not loaded:
  # @rpath/DoordeckSDK.framework/DoordeckSDK" unless they hand-rolled an embed
  # build phase, and static linkage was unsupported by RN's SPM integration.
  # Version mapping: pod 0.185.0 ships the same xcframework the previous SPM pin
  # (doordeck-headless-sdk-spm v1.128.0) pointed at. The module is still
  # "DoordeckSDK", so `import DoordeckSDK` in the Swift bridge is unchanged.
  s.dependency "DoordeckSDK", "0.185.0"

  # Install all React Native dependencies (React-Core, RCT-Folly, RCTRequired,
  # RCTTypeSafety, ReactCommon, codegen, New Architecture flags, etc.) via the
  # official helper. This resolves the correct spec sources for the installed RN
  # version — replacing the hand-maintained dependency list, which broke on RN
  # 0.86 (`Unable to find a specification for RCT-Folly`).
  install_modules_dependencies(s)
end
