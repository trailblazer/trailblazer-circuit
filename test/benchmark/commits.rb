# be ruby test/benchmark/commits.rb

commits = {
  "ref-1" => "master",
  "before optimizations" => "e80dc640b",
  "ref-2" => "master"
}

results = commits.values.collect do |tag|
  puts `git checkout #{tag}`
  result = `bundle exec ruby test/benchmark/ips.rb`
  result = result.split("\n").last.split("-").last

  [tag, result]
end

pp results

`git checkout master`
