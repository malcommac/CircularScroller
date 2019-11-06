Pod::Spec.new do |s|
  s.name         = "CircularScroller"
  s.version      = "0.1"
  s.summary      = ""
  s.description  = <<-DESC
    Your description here.
  DESC
  s.homepage     = "https://github.com/malcommac/CircularScroller"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author             = { "daniele margutti" => "hello@danielemargutti.com" }
  s.social_media_url   = ""
  s.ios.deployment_target = "9.0"
  s.source       = { :git => "https://github.com/malcommac/CircularScroller.git", :tag => s.version.to_s }
  s.source_files = 'Sources/**/*.swift'
  s.frameworks  = "UIKit"
  s.swift_version = "5.0"
end
