require 'erb'
require './league_of_legends.rb'

include LeagueOfLegends

ranks = spell_efficiency(150, 150, 150, false, 'damage per second')

renderer = ERB.new(File.read('template.erb'))
File.write('out.html', renderer.result())
