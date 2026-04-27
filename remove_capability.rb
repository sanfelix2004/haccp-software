require 'xcodeproj'

project_path = '/Users/frasanf004/Desktop/haccp-software/haccp-software.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'haccp-software' }

target.build_configurations.each do |config|
  config.build_settings.delete('CODE_SIGN_ENTITLEMENTS')
end

project.save
puts "Successfully removed entitlements link to allow personal team building."
