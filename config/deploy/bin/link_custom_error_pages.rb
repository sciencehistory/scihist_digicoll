#!/usr/bin/env ruby

# Makes a symlink to one of our custom static error pages at eg public/assets/500.html,
# from the standard rails static error location eg public/500.html.
#
# Only does it if the source file exists, so if something goes wrong and it doesn't,
# the default files from the repo are still there.
#
#     $ link_custom_error_pages.rb 500.html

require 'fileutils'

file_name = ARGV[0]

if file_name.nil? || file_name.empty?
  raise ArgumentError.new("Need an argument, but didn't get one. USAGE: #{$0} some_file_name.html")
end

dest_dir = File.expand_path('../../../public', File.dirname(__FILE__))
source_dir = File.join(dest_dir, "assets")

source_path = File.join(source_dir, file_name)
dest_path = File.join(dest_dir, file_name)

if File.exist?(source_path)
  FileUtils.ln_sf(source_path, dest_path, verbose: true)
else
  $stderr.puts "No source file at #{source_path} to copy"
end
