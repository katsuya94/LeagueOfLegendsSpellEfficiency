#!/usr/bin/env ruby

require 'optparse'
require 'erb'

require './league_of_legends.rb'

# Parse input

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

if scorer.nil? or ARGV.length != 5
  puts 'Usage: run.rb [-d] (--dps|--mana) base_ad bonus_ad ap cdr outfile'
  exit
end

base_attack_damage = ARGV[0].to_i
bonus_attack_damage = ARGV[1].to_i
spell_damage = ARGV[2].to_i
cdr = ARGV[3].to_i
outfile = ARGV[4]

include LeagueOfLegends

# Run calculations

data = spell_efficiency(base_attack_damage, bonus_attack_damage, spell_damage, cdr, duel, scorer)

# Output HTML

renderer = ERB.new(File.read('template.erb'))
File.write(outfile, renderer.result())
