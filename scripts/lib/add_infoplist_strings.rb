#!/usr/bin/env ruby
# Register ios/Runner/<lang>.lproj/InfoPlist.strings with the Xcode project
# as a single localized variant group, and record the languages in
# knownRegions.
#
#   add_infoplist_strings.rb <path/to/Runner.xcodeproj> <lang> [<lang>...]
#
# Without this the .lproj folders exist on disk but are never copied into
# the app bundle, so the ATT prompt silently falls back to the base English
# string. Idempotent: safe to re-run from bootstrap.
require 'xcodeproj'

proj_path = ARGV.shift or abort 'usage: add_infoplist_strings.rb <xcodeproj> <lang>...'
langs = ARGV
abort 'no languages given' if langs.empty?

project = Xcodeproj::Project.open(proj_path)
target  = project.targets.find { |t| t.name == 'Runner' } or abort 'no Runner target'
runner  = project.main_group['Runner'] or abort 'no Runner group'

langs.each { |l| project.root_object.known_regions << l }
project.root_object.known_regions.uniq!

group = runner.children.find do |c|
  c.is_a?(Xcodeproj::Project::Object::PBXVariantGroup) && c.name == 'InfoPlist.strings'
end
unless group
  group = project.new(Xcodeproj::Project::Object::PBXVariantGroup)
  group.name = 'InfoPlist.strings'
  group.source_tree = '<group>'
  runner << group
end

langs.each do |lang|
  next if group.children.any? { |c| c.name == lang }
  ref = project.new(Xcodeproj::Project::Object::PBXFileReference)
  ref.name = lang
  ref.path = "#{lang}.lproj/InfoPlist.strings"
  ref.source_tree = '<group>'
  ref.last_known_file_type = 'text.plist.strings'
  group << ref
end

phase = target.resources_build_phase
phase.add_file_reference(group, true) unless phase.files_references.include?(group)

project.save
puts "registered InfoPlist.strings for: #{langs.join(', ')}"
