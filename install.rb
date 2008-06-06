require 'fileutils'
monkeyBrains = File.dirname(__FILE__) + '/../../../config/monkeybrains.yml'
FileUtils.cp File.dirname(__FILE__) + '/monkeybrains.yml.tpl', monkeyBrains unless File.exist?(monkeyBrains)
puts IO.read(File.join(File.dirname(__FILE__), 'README'))