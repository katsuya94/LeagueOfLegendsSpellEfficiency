#!/usr/bin/env ruby

require 'optparse'
require 'erb'

require './league_of_legends.rb'

duel = false
scorer = nil

OptionParser.new do |opts|
  opts.on('-d', '--duel') do
    duel = true
  end 

  opts.on('--dps') do
    scorer = 'damage per second'
  end

  opts.on('--mana') do
    scorer = 'damage per mana'
  end
end.parse!

if scorer.nil? or ARGV.length != 3
  puts scorer
  puts ARGV
  puts 'Usage: run.rb [-d] (--dps|--mana) base_ad bonus_ad ap'
  exit
end

base_attack_damage = ARGV[0].to_i
bonus_attack_damage = ARGV[1].to_i
spell_damage = ARGV[2].to_i

include LeagueOfLegends

data = spell_efficiency(base_attack_damage, bonus_attack_damage, spell_damage, duel, scorer)

renderer = ERB.new(File.read('template.erb'))
File.write('out.html', renderer.result())
