require "test_helper"
require "benchmark/ips"


# Test how the new, less clumsy circuit-interface performs: 
#   (ctx, flow_options, **circuit_options)

range = 1..30
exec_context = T.def_tasks(*range.collect { |i| i.to_s.to_sym })

methods = range.collect { |i| [i, exec_context.method(i.to_s.to_sym)] }.to_h

def build_activity(methods, circuit_class: Trailblazer::Activity::Circuit, config: {})
  map = methods.collect { |i, method| [method, {Trailblazer::Activity::Right => methods[i + 1]}] }.to_h

  circuit = circuit_class.new(map, [methods.values.last], start_task: methods.values.first)
  schema = Trailblazer::Activity::Schema.new(circuit, {}, nil, config)
  activity = Trailblazer::Activity.new(schema)
end

activity = build_activity(methods)

def run_activity_with_old_circuit_interface(activity, ctx)
  activity.([ctx, {}], runner: Trailblazer::Activity::Circuit::Runner)
end

MyRunner = ->(task, ctx, flow_options, **circuit_options) { task.(ctx, flow_options, **circuit_options) }

methods_new = range.collect { |i|
  # name = "#{i}_positional"

  define_method(i.to_s) do |ctx, flow_options, **|
    ctx[:seq] << i
    return Trailblazer::Activity::Right, ctx, flow_options
  end

  [i, method(i.to_s)]
}.to_h


# methods = range.collect { |i, method| method("#{i}_positional") }
  # pp methods

  class Bla < Trailblazer::Activity::Circuit
    def call(ctx, flow_options, start_task: @start_task, runner: Runner, **circuit_options)
      task = start_task

      loop do
        last_signal, ctx, flow_options = runner.( # we silently discard returned {circuit_options}.
          task,
          ctx, flow_options,
          **circuit_options,
          runner: runner
        )

        # Stop execution of the circuit when we hit a terminus.
        return [last_signal, ctx, flow_options] if @termini.include?(task)

        if (next_task = next_for(task, last_signal))
          task = next_task
        else
          raise IllegalSignalError.new(
            task,
            signal: last_signal,
            outputs: @map[task],
            exec_context: circuit_options[:exec_context] # passed at run-time from DSL
          )
        end
      end
    end
  end

activity_with_positional_interface = build_activity(methods_new, circuit_class: Bla)

def run_activity_with_positional_circuit_interface(activity, ctx, runner: MyRunner)
  activity.call_2(ctx, {}, runner: runner)
end

ctx = {model: Object, params: {}, seq: []}
signal, (ctx, _) = run_activity_with_old_circuit_interface(activity, ctx)
puts "@@@@@ #{ctx.inspect}"

ctx = {model: Object, params: {}, seq: []}
signal, (ctx, _) = run_activity_with_positional_circuit_interface(activity_with_positional_interface, ctx)
puts "@@@@@ #{ctx.inspect}"

### Benchmark simple {Activity}s without taskWrap, just checking how the circuit-interface signature performs.
#
# Benchmark.ips do |x|
#   x.report("args array") { run_activity_with_old_circuit_interface(activity, ctx) }
#   x.report("positional") { run_activity_with_positional_circuit_interface(activity_with_positional_interface, ctx) }
#
#   x.compare!
# end

=begin

1. (ctx, flow_options), **circuit vs. ctx, flow_options, **circuit_options
Comparison:
          positional:    30991.5 i/s
          args array:    28627.5 i/s - 1.08x  (± 0.00) slower


for both 3.3.6 and 3.4.1

=end

def add_1_old_style(wrap_ctx, original_args)
  ctx = original_args[0][0]

  ctx[:seq] << 1

  return wrap_ctx, original_args
end

task_wrap = Trailblazer::Activity::TaskWrap::INITIAL_TASK_WRAP
task_wrap = Trailblazer::Activity::Adds.(
  task_wrap,
  [method(:add_1_old_style), id: "0-1", prepend: "task_wrap.call_task"],
  [method(:add_1_old_style), id: "1-1", append: "task_wrap.call_task"]
)

wrap_static = Hash.new(task_wrap)
activity = build_activity(methods, config: {wrap_static: wrap_static})

def run_traditional_with_tw(activity, ctx)
  Trailblazer::Activity::TaskWrap.invoke(activity, [ctx, {}])
end

ctx = {model: Object, params: {}, seq: []}
signal, (ctx, _) = run_traditional_with_tw(activity, ctx)
puts "@@@@@ #{ctx.inspect}"


def add_1_new_style(wrap_ctx, flow_options, **)
  ctx = wrap_ctx[:original_ctx]

  ctx[:seq] << 1

  return wrap_ctx, flow_options
end

def call_task_new(wrap_ctx, flow_options, **circuit_options)
  task = wrap_ctx[:task]

  return_signal, return_args = task.call(wrap_ctx[:original_ctx], flow_options, **circuit_options)

  # DISCUSS: do we want original_args here to be passed on, or the "effective" return_args which are different to original_args now?
  wrap_ctx = wrap_ctx.merge(
    return_signal: return_signal,
    return_args:   return_args
  )

  return wrap_ctx, flow_options
end

module TWRunner
  def self.call(task, ctx, flow_options, **circuit_options)
    wrap_ctx = {
      task: task,
      original_ctx: ctx,
      original_circuit_options: circuit_options
    }

    # this pipeline is "wrapped around" the actual `task`.
    task_wrap_pipeline = Trailblazer::Activity::TaskWrap::Runner.merge_static_with_runtime(task, **circuit_options, wrap_runtime: {}) || raise

    # We save all original args passed into this Runner.call, because we want to return them later after this wrap
    # is finished.
    # original_args = [args, circuit_options]

    # call the wrap {Activity} around the task.
    # wrap_ctx, _ = task_wrap_pipeline.(wrap_ctx, flow_options, **circuit_options) # we omit circuit_options here on purpose, so the wrapping activity uses the default, plain Runner.
    task_wrap_pipeline.to_a.each do |id, task|
      # wrap_ctx, flow_options = task.(wrap_ctx, flow_options, ) # 2. this is a bit faster, and apart from that: do we need the circuit_options?

      # DISCUSS: in 99.9% we don't need the **circuit_options (they cannont be changed/returned anyway).
      #          so if a special circuit needs **circuit_options (because the task might be an Activity),
      #          we can use a special Runner?
      #
      #          BENCHMARK: passing the **circuit_options makes it 1.06x slower, if omitted, the args version is 1.04x slower.
      wrap_ctx, flow_options = task.(wrap_ctx, flow_options, **circuit_options) # we omit circuit_options here on purpose, so the wrapping activity uses the default, plain Runner.
      # wrap_ctx, flow_options = task.(wrap_ctx, flow_options) # we omit circuit_options here on purpose, so the wrapping activity uses the default, plain Runner.
    end

    return wrap_ctx[:return_signal], wrap_ctx[:return_args]
  end
end

# task_wrap = Trailblazer::Activity::TaskWrap::INITIAL_TASK_WRAP
task_wrap = Trailblazer::Activity.Pipeline("task_wrap.call_task" => method(:call_task_new))
task_wrap = Trailblazer::Activity::Adds.(
  task_wrap,
  [method(:add_1_new_style), id: "0-1", prepend: "task_wrap.call_task"],
  [method(:add_1_new_style), id: "1-1", append: "task_wrap.call_task"]
)

wrap_static = Hash.new(task_wrap)

activity_with_positional_interface = build_activity(methods_new, circuit_class: Bla, config: {wrap_static: wrap_static})

ctx = {model: Object, params: {}, seq: []}
signal, (ctx, _) = run_activity_with_positional_circuit_interface(activity_with_positional_interface, ctx, runner: TWRunner)
puts "@@@@@ #{ctx.inspect}"

### Benchmark with taskWrap, where both Pipeline and tw steps have the same interface as the activity
#
Benchmark.ips do |x|
  x.report("args array") {
    ctx = {model: Object, params: {}, seq: []}
    signal, (ctx, _) = run_traditional_with_tw(activity, ctx)
  }
  x.report("positional") {
    ctx = {model: Object, params: {}, seq: []}
    signal, (ctx, _) = run_activity_with_positional_circuit_interface(activity_with_positional_interface, ctx, runner: TWRunner)
  }

  x.compare!
end

=begin

1. (ctx, flow_options), **circuit vs. ctx, flow_options, **circuit_options
Comparison:
          positional:    30991.5 i/s
          args array:    28627.5 i/s - 1.08x  (± 0.00) slower


for both 3.3.6 and 3.4.1

=end
