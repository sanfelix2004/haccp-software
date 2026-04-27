require 'xcodeproj'

project_path = '/Users/frasanf004/Desktop/haccp-software/haccp-software.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'haccp-software' }

entitlements_path = 'haccp-software/haccp-software.entitlements'

target.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = entitlements_path
end

project.save
puts "Successfully linked entitlements in build settings."
