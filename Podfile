# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'
platform :osx, '10.12'

target 'Mr. Puppet Hub' do
  use_frameworks!

  pod 'Sparkle'
  pod 'AppCenter'
end

post_install do |installer|
	# Sign the Sparkle helper binaries to pass App Notarization.
	system("codesign --force -o runtime -s 'Developer ID Application: Thinko, LLC (H7BXRR563Q)' Pods/Sparkle/Sparkle.framework/Resources/Autoupdate.app/Contents/MacOS/Autoupdate")
	system("codesign --force -o runtime -s 'Developer ID Application: Thinko, LLC (H7BXRR563Q)' Pods/Sparkle/Sparkle.framework/Resources/Autoupdate.app/Contents/MacOS/fileop")
end