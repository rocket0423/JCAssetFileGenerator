Pod::Spec.new do |s|
  s.name           = "BPAssetFileGenerator"
  s.version        = "0.0.1"
  s.summary        = "A set of executables for generating helper files for all your assets"
  s.homepage       = "http://www.bitsuites.com"
  s.license        = 'MIT'
  s.author         = { "Justin Carstens" => "justinc@bitsuites.com" }

  s.source         = { :git => "git@github.com:BitSuites/BPAssetFileGenerator.git" }
  s.platform       = :ios, '9.0'
  s.preserve_paths = 'Executables/*'
end

