#!/usr/bin/env ruby
# Optional differential check against a separately obtained, pinned HOJ checkout.
# No reference implementation is bundled or downloaded by this script.
require 'json'

commit = 'f5d1ee4e3616c1b2cf79e70a0ccee267b5f09ea3'
abort 'Usage: ruby scripts/check_hoj_reference.rb PATH_TO_QUOLC_HOJ' unless ARGV.length == 1
reference = File.expand_path(ARGV[0])
actual = IO.popen(['git', '-C', reference, 'rev-parse', 'HEAD'], &:read).strip
abort "Expected reference commit #{commit}; got #{actual}" unless actual == commit
root = File.expand_path('..', __dir__)
fixtures = JSON.parse(File.read(File.join(root, 'Tests/HerbertCoreTests/Fixtures/hoj-compatibility.json')))
problems = JSON.parse(File.read(File.join(root, 'Sources/HerbertCore/Resources/original-problems.json')))
solutions = JSON.parse(File.read(File.join(root, 'Tests/HerbertCoreTests/Fixtures/original-solutions.json')))
study = JSON.parse(File.read(File.join(root, 'Tests/HerbertCoreTests/Fixtures/community-study-solutions.json')))

Dir.chdir(File.join(reference, 'judge')) do
  require './judge'
  fixtures.each do |fixture|
    code = HCode.parse(fixture.fetch('source'))
    abort "Rejected #{fixture['name']}" unless code
    code.init
    output = ''
    10_000.times do
      break if code.isstop || output.length >= fixture.fetch('commands').length
      command = code.turn
      output << command if command
    end
    abort "Trace mismatch: #{fixture['name']}" unless output == fixture.fetch('commands')
    abort "Byte mismatch: #{fixture['name']}" unless CountSrc(fixture.fetch('source')) == fixture.fetch('bytes')
  end
  corridor = JSON.parse(File.read(File.join(root, 'Sources/HerbertCommunity/Resources/problems.json'))).find { |p| p['id'] == 1 }
  field = corridor.fetch('rows').join("\n") + "\n7"
  result = HJudge.new(field, 'lsrssss').judge
  abort 'Wall collision did not continue to completion' unless result.status == 'Passed System Test'
  # Bound even a broken reference interpreter without changing its source.
  HCode.prepend(Module.new do
    def turn
      raise 'Reference replay exceeded 10,000 interpreter turns' if step >= 10_000
      super
    end
  end)
  problems.zip(solutions).each do |problem, solution|
    abort 'Reference solution IDs differ' unless problem.fetch('id') == solution.fetch('id')
    abort "Rejected lesson #{problem['id']}" unless HCode.parse(solution.fetch('source'))
    field = problem.fetch('rows').join("\n") + "\n" + problem.fetch('byteLimit').to_s
    result = HJudge.new(field, solution.fetch('source')).judge
    abort "Failed L#{problem.fetch('lesson').fetch('order')}: #{result.status}" unless result.status == 'Passed System Test'
  end
  community = JSON.parse(File.read(File.join(root, 'Sources/HerbertCommunity/Resources/problems.json')))
  study.each do |solution|
    problem = community.find { |p| p['id'] == solution.fetch('id') }
    abort 'Study solution exceeds original byte budget' if CountSrc(solution.fetch('source')) > problem.fetch('byteLimit')
    field = problem.fetch('rows').join("\n") + "\n" + problem.fetch('byteLimit').to_s
    result = HJudge.new(field, solution.fetch('source')).judge
    abort "Failed community #{problem['id']}: #{result.status}" unless result.status == 'Passed System Test'
  end
end
puts "PASS: #{fixtures.length} command/byte fixtures, #{problems.length} originals, #{study.length} community study solutions, and community #0001 wall collision at #{commit}"
