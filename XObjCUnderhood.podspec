Pod::Spec.new do |s|
  s.name         = 'XObjCUnderhood'
  s.version      = '1.0.0'
  s.license      = 'MIT'
  s.summary      = 'Disclose the Objective-C classes/interfaces under the hood'
  s.homepage     = 'https://github.com/xareelee/XObjCUnderhood'
  s.authors      = { 'Kang-Yu Xaree Lee' => 'xareelee@gmail.com' }
  s.source       = { :git => "https://github.com/xareelee/XObjCUnderhood.git", :tag => s.version.to_s, :submodules =>  true }
  
  s.requires_arc = true
  s.default_subspecs = 'Core'

  s.subspec 'Core' do |ss|
    ss.public_header_files = 'XObjCUnderhood/Core/*.h'
    ss.source_files = 'XObjCUnderhood/Core/*.{h,m}'
    ss.frameworks = 'Foundation'
    ss.dependency 'M13OrderedDictionary'
  end

end
