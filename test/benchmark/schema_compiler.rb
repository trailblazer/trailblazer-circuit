require "test_helper"

gem "benchmark-ips"
require "benchmark/ips"
Activity = Trailblazer::Activity
Schema = Activity::Schema

intermediate = Schema::Intermediate.new(
  {
    Schema::Intermediate::TaskRef(:a) => [Schema::Intermediate::Out(:success, :b)],
    Schema::Intermediate::TaskRef(:b) => [Schema::Intermediate::Out(:success, :c)],
    Schema::Intermediate::TaskRef(:c) => [Schema::Intermediate::Out(:success, :d)],
    Schema::Intermediate::TaskRef(:d) => [Schema::Intermediate::Out(:success, :e)],
    Schema::Intermediate::TaskRef(:f) => [Schema::Intermediate::Out(:success, :g)],
    Schema::Intermediate::TaskRef(:h) => [Schema::Intermediate::Out(:success, :i)],
    Schema::Intermediate::TaskRef(:j) => [Schema::Intermediate::Out(:success, :k)],
    Schema::Intermediate::TaskRef(:l) => [Schema::Intermediate::Out(:success, :m)],
    Schema::Intermediate::TaskRef(:n) => [Schema::Intermediate::Out(:success, :o)],
    Schema::Intermediate::TaskRef(:c) => [Schema::Intermediate::Out(:success, :d)],
    Schema::Intermediate::TaskRef(:p) => [Schema::Intermediate::Out(:success, :q)],
    Schema::Intermediate::TaskRef(:q) => [Schema::Intermediate::Out(:success, nil)]
  },
  [:q], # terminus
  [:a]  # start
)

# DISCUSS: in Ruby 3, procs created from the same block are identical: https://rubyreferences.github.io/rubychanges/3.0.html#proc-and-eql
step = ->((ctx, flow), **circuit_options) { ctx += [circuit_options[:activity]]; [Activity::Right, [ctx, flow]] }

implementation = {
  :a => Schema::Implementation::Task(step.clone, [Activity::Output(Activity::Right, :success)], []),
  :b => Schema::Implementation::Task(step.clone, [Activity::Output(Activity::Right, :success)], []),
  :c => Schema::Implementation::Task(step.clone, [Activity::Output(Activity::Right, :success)], []),
  :d => Schema::Implementation::Task(step.clone, [Activity::Output(Activity::Right, :success)], []),
  :e => Schema::Implementation::Task(step.clone, [Activity::Output(Activity::Right, :success)], []),
  :f => Schema::Implementation::Task(step.clone, [Activity::Output(Activity::Right, :success)], []),
  :g => Schema::Implementation::Task(step.clone, [Activity::Output(Activity::Right, :success)], []),
  :h => Schema::Implementation::Task(step.clone, [Activity::Output(Activity::Right, :success)], []),
  :i => Schema::Implementation::Task(step.clone, [Activity::Output(Activity::Right, :success)], []),
  :j => Schema::Implementation::Task(step.clone, [Activity::Output(Activity::Right, :success)], []),
  :k => Schema::Implementation::Task(step.clone, [Activity::Output(Activity::Right, :success)], []),
  :l => Schema::Implementation::Task(step.clone, [Activity::Output(Activity::Right, :success)], []),
  :m => Schema::Implementation::Task(step.clone, [Activity::Output(Activity::Right, :success)], []),
  :n => Schema::Implementation::Task(step.clone, [Activity::Output(Activity::Right, :success)], []),
  :o => Schema::Implementation::Task(step.clone, [Activity::Output(Activity::Right, :success)], []),
  :p => Schema::Implementation::Task(step.clone, [Activity::Output(Activity::Right, :success)], []),
  :q => Schema::Implementation::Task(step.clone, [Activity::Output(Activity::Right, :success)], []),
}

# activity = Activity.new(Schema::Intermediate.(intermediate, implementation))


intermediate_new = Schema::Intermediate.new(
  {
    Schema::Intermediate::TaskRef(:a) => [Schema::Intermediate::Out(:success, :b)],
    Schema::Intermediate::TaskRef(:b) => [Schema::Intermediate::Out(:success, :c)],
    Schema::Intermediate::TaskRef(:c) => [Schema::Intermediate::Out(:success, :d)],
    Schema::Intermediate::TaskRef(:d) => [Schema::Intermediate::Out(:success, :e)],
    Schema::Intermediate::TaskRef(:f) => [Schema::Intermediate::Out(:success, :g)],
    Schema::Intermediate::TaskRef(:h) => [Schema::Intermediate::Out(:success, :i)],
    Schema::Intermediate::TaskRef(:j) => [Schema::Intermediate::Out(:success, :k)],
    Schema::Intermediate::TaskRef(:l) => [Schema::Intermediate::Out(:success, :m)],
    Schema::Intermediate::TaskRef(:n) => [Schema::Intermediate::Out(:success, :o)],
    Schema::Intermediate::TaskRef(:c) => [Schema::Intermediate::Out(:success, :d)],
    Schema::Intermediate::TaskRef(:p) => [Schema::Intermediate::Out(:success, :q)],
    Schema::Intermediate::TaskRef(:q) => []
  },
  {:q => :success}, # terminus
  :a  # start
)




Benchmark.ips do |x|
  x.report("Intermediate.call") { Activity.new(Schema::Intermediate.(intermediate, implementation)) }
  x.report("Compiler.call")     { Activity.new(Schema::Intermediate::Compiler.(intermediate_new, implementation)) }
  # x.report("doublesplat") { doublesplat(first, kws) }

  x.compare!
end
