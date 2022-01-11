# avoid ruby warnings in our logs related to a regular expressions in the device_detector
# gem, a known problem that is unlikely to be fixed upsteram.
# https://github.com/podigee/device_detector/issues/91

if device_detector_source_path = Gem.loaded_specs['device_detector']&.full_gem_path
  parser_source_file_path = (Pathname.new(device_detector_source_path) + "lib/device_detector/parser.rb").to_s
  Warning.ignore(/regular expression/, parser_source_file_path)
end
