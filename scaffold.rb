require 'xcodeproj'
require 'fileutils'

project_path = '/Users/frasanf004/Desktop/haccp-software/haccp-software.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

base_dir = '/Users/frasanf004/Desktop/haccp-software/haccp-software'
main_group = project.main_group.find_subpath('haccp-software', true)
main_group.set_source_tree('<group>')

# Define the structure
structure = {
  'HACCPManager' => {
    'App' => ['AppRouter.swift', 'AppState.swift', 'AppConfig.swift'],
    'Core' => {
      'Network' => ['ApiClient.swift', 'ApiEndpoint.swift', 'NetworkError.swift'],
      'Auth' => ['AuthManager.swift', 'TokenStorage.swift'],
      'Storage' => ['LocalDatabase.swift', 'CacheManager.swift'],
      'Components' => ['PrimaryButton.swift', 'LoadingView.swift', 'ErrorView.swift'],
      'Utils' => [],
      'Extensions' => []
    },
    'Features' => {
      'Authentication' => [],
      'Dashboard' => [],
      'Users' => [],
      'Products' => [],
      'Labels' => [],
      'Temperatures' => [],
      'Defrost' => [],
      'BlastChilling' => [],
      'Cleaning' => [],
      'Checklists' => [],
      'Reports' => [],
      'Settings' => []
    },
    'Resources' => {
      'MockData' => [],
      '.' => ['Localizable.strings']
    }
  }
}

def create_files_and_groups(hash_or_array, parent_dir, parent_group, target)
  if hash_or_array.is_a?(Hash)
    hash_or_array.each do |key, value|
      if key == '.'
        create_files_and_groups(value, parent_dir, parent_group, target)
      else
        dir = File.join(parent_dir, key)
        FileUtils.mkdir_p(dir)
        group = parent_group.find_subpath(key, true)
        group.set_source_tree('<group>')
        create_files_and_groups(value, dir, group, target)
      end
    end
  elsif hash_or_array.is_a?(Array)
    hash_or_array.each do |file_name|
      file_path = File.join(parent_dir, file_name)
      unless File.exist?(file_path)
        if file_name.end_with?('.swift')
          File.write(file_path, "import Foundation\nimport SwiftUI\n\n// Placeholder for #{file_name}\n")
        elsif file_name.end_with?('.strings')
          File.write(file_path, "/* Localizable.strings */\n")
        else
          FileUtils.touch(file_path)
        end
      end
      
      # Add to xcodeproj group if not already there
      file_ref = parent_group.files.find { |f| f.path == file_name }
      if file_ref.nil?
        file_ref = parent_group.new_file(file_path)
      end
      
      # Add to target compile sources or resources
      if file_name.end_with?('.swift')
        unless target.source_build_phase.files_references.include?(file_ref)
          target.source_build_phase.add_file_reference(file_ref)
        end
      elsif file_name.end_with?('.strings')
        unless target.resources_build_phase.files_references.include?(file_ref)
          target.resources_build_phase.add_file_reference(file_ref)
        end
      end
    end
  end
end

create_files_and_groups(structure, base_dir, main_group, target)

project.save
puts "Xcode project successfully modified."
