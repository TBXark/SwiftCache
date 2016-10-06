Pod::Spec.new do |s|
	s.name     = 'SCache.swift'
	s.version  = '0.1.0'

	s.license  = { :type => 'MIT', :file => 'LICENSE' }
	s.summary  = 'A pure swift cache framework inspired by YYCache'
	s.homepage = 'https://github.com/TBXark/SwiftCache'
	s.author   = { 'TBXark' => 'tbxark@outlook.com' }
	s.source   = { :git => 'https://github.com/TBXark/SwiftCache', :tag => "v#{s.version}" }
	s.module_name = 'SCache'

	s.ios.deployment_target = '8.0'
	s.osx.deployment_target = '10.9'
	s.watchos.deployment_target = '2.0'

	s.source_files = 'SCache/**/*.{h,swift}'
	s.module_map = 'Support/module.modulemap'
	s.framework = 'Foundation'
	s.library = 'sqlite3'
end
