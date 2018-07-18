Pod::Spec.new do |s|
  s.name           = "JCAssetFileGenerator"
  s.version        = "0.0.1"
  s.summary        = "A set of executables for generating helper files for all your assets"
  s.license        = 'MIT'
  s.author         = { "Justin Carstens" => "jrcarste2@gmail.com" }
  s.homepage       = "https://github.com/rocket0423/JCAssetFileGenerator"
  s.source         = { :git => "https://github.com/rocket0423/JCAssetFileGenerator.git" }
  s.platform       = :ios, '9.0'
  s.preserve_paths = 'Executables/*'
end

