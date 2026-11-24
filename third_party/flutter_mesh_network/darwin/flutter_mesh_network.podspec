#
# CocoaPods podspec for the shared Darwin sources.
# `sharedDarwinSource: true` makes the Flutter tool look for this file under
# `darwin/`; upstream 0.1.3 only shipped the iOS podspec under `ios/`, which
# aborts every `flutter build` on Flutter 3.32. This copy fixes that.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_mesh_network'
  s.version          = '0.1.3'
  s.summary          = 'Flutter Mesh Network plugin for iOS — MultipeerConnectivity and BLE Peripheral.'
  s.description      = <<-DESC
Cross-platform mesh networking plugin. On iOS this wraps MultipeerConnectivity
(peer discovery, encrypted sessions, messaging) and CoreBluetooth peripheral
mode (GATT server, BLE advertising, chunked message assembly).
                       DESC
  s.homepage         = 'https://github.com/salihyildirim/flutter_mesh_network'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Salih Yildirim' => 'salihyildirimce@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'flutter_mesh_network/Sources/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  s.resource_bundles = {
    'flutter_mesh_network_privacy' => [
      'flutter_mesh_network/Sources/flutter_mesh_network/Resources/PrivacyInfo.xcprivacy'
    ]
  }
end
