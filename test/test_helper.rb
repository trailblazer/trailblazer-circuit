require "trailblazer/circuit"
require "minitest/autorun"

Minitest::Spec.class_eval do
  def assert_equal(asserted, expected, *args)
    super(expected, asserted, *args)
  end

  require "trailblazer/core"
  include Trailblazer::Core::Utils::Assertions
  T = Trailblazer::Core

  # module Minitest::Spec::Implementing
  #   extend T.def_tasks(:a, :b, :c, :d, :f, :g)
  # end

  Left = Class.new
  Right = Class.new
end

# TODO: move me to core-utils. test me.
module AssertRun
  def assert_run(circuit, processor: Trailblazer::Circuit::Processor, exec_context: nil, terminus: nil, seq:, flow_options: {}, **application_ctx)
    lib_ctx = {}
    lib_ctx = exec_context ? lib_ctx.merge(exec_context: exec_context) : lib_ctx
    circuit_options = {}
    circuit_options = circuit_options.merge(runner: Trailblazer::Circuit::Node::Runner)
    circuit_options = circuit_options.merge(context_implementation: Trailblazer::Circuit::Context) # FIXME: remove

    flow_options = {application_ctx: {seq: [], **application_ctx}, **flow_options}

    lib_ctx, flow_options, signal = processor.(circuit, lib_ctx, flow_options, nil, **circuit_options)

    assert_equal signal, terminus
    assert_equal flow_options[:application_ctx][:seq], seq # FIXME: test all ctx variables.

    return lib_ctx, flow_options, signal
  end
end

class Capture < Struct.new(:name, :pollute, :return_signal)
  Undefined = Class.new

  def initialize(name, pollute = nil, return_signal = Undefined)
    super
  end

  def call(lib_ctx, flow_options, signal, **kwargs)
    flow_options = flow_options.merge(
      name => [
        lib_ctx.clone,
        flow_options.clone,
        signal,
        kwargs
      ]
    )

    lib_ctx = lib_ctx.merge(pollute) if pollute

    signal = return_signal unless return_signal == Undefined

    return lib_ctx, flow_options, signal
  end
end

Minitest::Spec.class_eval do
  require "trailblazer/core"
  CU = Trailblazer::Core::Utils

  include AssertRun

  let(:_A) { Trailblazer } # TODO: remove.

  def Pipeline(*args)
    Trailblazer::Circuit::Builder.Pipeline(*args)
  end
end


# TODO: Context#freeze
module Trailblazer
  class Context < Struct.new(:shadowed, :mutable)
    def []=(key, value)
      mutable[key] = value

      # @to_h[key] = value
    end

    def [](key)
      # raise
      mutable[key] || shadowed[key] # FIXME.
    end

    def merge(variables)
      # raise
      # puts variables.inspect
      Context.new(shadowed, mutable.merge(variables))
    end

    def decompose
      return shadowed, mutable
    end

    def to_h
      # return @to_h
      shadowed.to_h.merge(mutable) # DISCUSS: shadowed.to_h we only should do once, at instantiation!
    end

    def to_hash # implicit conversion to Hash.
      to_h
    end

    def self.scope_FIXME(outer_ctx, whitelisted_variables, mutable)
      new_ctx = outer_ctx

      if whitelisted_variables
        new_ctx = whitelisted_variables.collect { |key| [key, outer_ctx[key]] }.to_h
      end

      Trailblazer::Context.new(new_ctx, mutable.dup) # FIXME: add tests where we make sure we're dupping here, otherwise it starts bleeding!
    end

    def self.unscope_FIXME!(outer_ctx, ctx, copy_to_outer_ctx)
      _FIXME_outer_ctx, mutable = ctx.decompose

                  copy_to_outer_ctx.each do |key| # FIXME: use logic from variable-mapping here.
                    # DISCUSS: is merge! and slice faster? no it's not.
                    # outer_ctx[key] = mutable[key] # if the task didn't write anything, we need to ask to big scoped ctx.
                    outer_ctx[key] = ctx[key] # if the task didn't write anything, we need to ask to big scoped ctx.
                  end

                  # raise "some pipes don't update :stack, that's why it is nil in mutable[:stack]"

      outer_ctx
    end
  end

  def self.Context(shadowed)
    Context.new(shadowed, {})
  end

  class MyContext_No_Slice
    def self.scope_FIXME(outer_ctx, whitelisted_variables, variables_to_merge)
      new_ctx =
        if whitelisted_variables
          whitelisted_variables.collect do |k|
            [k, outer_ctx[k]]
          end.to_h
          # outer_ctx.slice(*whitelisted_variables) # NOTE: feel free to improve runtime performance here, see benchmark # FIXME: insert link
        else
          outer_ctx
        end
# FIXME: -test that we ALWAYS return a new hash instance.
      new_ctx.merge(variables_to_merge)
    end

    def self.unscope_FIXME!(outer_ctx, ctx, copy_to_outer_ctx)
      # new_variables = ctx.slice(*copy_to_outer_ctx)
      new_variables = copy_to_outer_ctx.collect do |k|
        [k, ctx[k]]
      end.to_h

      outer_ctx.merge(new_variables)
    end
  end
end

class IO___
  # Lib interface.
  # def init_aggregate(lib_ctx, flow_options, signal, **)
  #   lib_ctx[:aggregate] = {}

  #   return lib_ctx, flow_options, signal
  # end

  # Lib interface.
  def add_value_to_aggregate(lib_ctx, flow_options, signal, value:, aggregate:, **)
    lib_ctx[:aggregate] = aggregate.merge(value)

    return lib_ctx, flow_options, signal
  end

  # Lib interface.
  def save_original_application_ctx(lib_ctx, flow_options, signal, **)
    # DISCUSS: do we need this?
    lib_ctx[:original_application_ctx] = flow_options[:application_ctx] # the "outer ctx".

    return lib_ctx, flow_options, signal
  end

  # Lib interface.
  def swap___(lib_ctx, flow_options, signal, original_application_ctx:, aggregate:, **)
    # new_application_ctx = original_application_ctx.merge(aggregate) # DISCUSS: how to write on outer ctx?
    aggregate.each do |k, v|
      original_application_ctx[k] = v # FIXME: should we use Context#merge here? do we want a new ctx?

    end

    flow_options = flow_options.merge(application_ctx: original_application_ctx)

    return lib_ctx, flow_options, signal
  end


  def create_application_ctx(lib_ctx, flow_options, signal, aggregate:, **)
    flow_options = flow_options.merge(application_ctx: Trailblazer::Context(aggregate))

    return lib_ctx, flow_options, signal
  end
end

module Fixtures
  class Create
    # Step interface.
    def model(ctx, params:, **kws)
      ctx[:spam] = false
      ctx[:model] = "Object #{params[:id]} / #{kws.inspect}"
    end

    # Add params[:slug],
    def my_model_input(ctx, params:, slug:, **)
      {
        params: params.merge(slug: slug)
      }
    end

    # In() => MoreModelInput
    class MoreModelInput
      # Step interface.
      def self.call(ctx, slug:, **)
        {
          more: slug
        }
      end
    end

    # Out() => [:model]
    # Step interface.
    def my_model_output(ctx, model:, **)
      {
        model: model
      }
    end
  end

  class Validate
    # Step interface.
    def run_checks(ctx, params:, model:, **)
      if params[:song]
        return true
      else
        ctx[:errors] = [model, :song]
        return false
      end
    end

    # Step interface.
    def title_length_ok?(ctx, params:, **)
      return false unless params[:song][:title]

      return true
    end
  end

  class Save
    # Step interface.
    def self.call(ctx, model:, **)
      ctx[:save] = model
    end
  end

  def self.pipeline_circuit(*args)
    Trailblazer::Circuit::Builder.Pipeline(*args)
  end

  def self.fixtures
    io = IO___.new

    # In() => :my_model_input
    my_model_input_pipe = Trailblazer::Activity::Circuit::Builder.Pipeline(
      [
        :invoke_instance_method,
        :my_model_input,
        Trailblazer::Activity::Circuit::Task::Adapter::StepInterface::InstanceMethod,
        {exec_context: Create.new},
        Trailblazer::Activity::Circuit::Node::Scoped,
        {copy_to_outer_ctx: [:value]}
      ],
      [:add_value_to_aggregate, :add_value_to_aggregate],
    )

    more_model_input_pipe = Trailblazer::Activity::Circuit::Builder.Pipeline(
      [:invoke_callable, Create::MoreModelInput, Trailblazer::Activity::Circuit::Task::Adapter::StepInterface], # FIXME: problem here is, we're writing to lib_ctx[:value]
      [:add_value_to_aggregate, :add_value_to_aggregate],
    )

    my_model_output_pipe = Trailblazer::Activity::Circuit::Builder.Pipeline(
      [:invoke_instance_method, :my_model_output, Trailblazer::Activity::Circuit::Task::Adapter::StepInterface::InstanceMethod, {exec_context: Create.new}, Trailblazer::Activity::Circuit::Node::Scoped, {copy_to_outer_ctx: [:value]}],
      [:add_value_to_aggregate, :add_value_to_aggregate],
    )

    # !!! requires: {exec_context: io}
    model_input_pipe = Trailblazer::Activity::Circuit::Builder.Pipeline(
      [:save_original_application_ctx, :save_original_application_ctx],
      # [:init_aggregate, :init_aggregate],
      [:my_model_input, my_model_input_pipe, Trailblazer::Activity::Circuit::Processor, {}, Trailblazer::Activity::Circuit::Node::Scoped, {copy_to_outer_ctx: [:aggregate]}],     # user filter.
      [:more_model_input, more_model_input_pipe, Trailblazer::Activity::Circuit::Processor, {}, Trailblazer::Activity::Circuit::Node::Scoped, {copy_to_outer_ctx: [:aggregate]}], # user filter.

      [:create_application_ctx, :create_application_ctx, Trailblazer::Activity::Circuit::Task::Adapter::LibInterface::InstanceMethod],
    )

    # !!! requires: {exec_context: io}
    model_output_pipe = Trailblazer::Activity::Circuit::Builder.Pipeline(
      # [:init_aggregate, :init_aggregate],                          # DISCUSS: why do we need Scoped for my_model_output?
      [:my_model_output, my_model_output_pipe, Trailblazer::Activity::Circuit::Processor, {}, Trailblazer::Activity::Circuit::Node::Scoped, {copy_to_outer_ctx: [:aggregate]}],     # user filter.
      [:swap___, :swap___, Trailblazer::Activity::Circuit::Task::Adapter::LibInterface::InstanceMethod],
    )


    model_instance_method_pipe = Trailblazer::Activity::Circuit::Builder::Step.InstanceMethod(:model)

    # model_instance_method_pipe = Trailblazer::Activity::Circuit::Adds.(model_instance_method_pipe,

    # [
    # :after]
    #   )
    # [:bla, ->(ctx, lib_ctx, signal, **) { raise signal.inspect }, Trailblazer::Activity::Circuit::Task::Adapter::LibInterface, {}, Trailblazer::Activity::Circuit::Node, {}],


    model_tw_pipe = Trailblazer::Activity::Circuit::Builder.TaskWrap(
      [:input, model_input_pipe, Trailblazer::Activity::Circuit::Processor, {exec_context: io, aggregate: {}.freeze}, Trailblazer::Activity::Circuit::Node::Scoped, {copy_to_outer_ctx: [:original_application_ctx], return_outer_signal: true, copy_from_outer_ctx: []}], # change {:application_ctx}.
      [:"task_wrap.call_task", model_instance_method_pipe, Trailblazer::Activity::Circuit::Processor, {}, Trailblazer::Activity::Circuit::Node::Scoped],
      [:output, model_output_pipe, Trailblazer::Activity::Circuit::Processor, {exec_context: io, aggregate: {}.freeze}, Trailblazer::Activity::Circuit::Node::Scoped, {return_outer_signal: true, copy_from_outer_ctx: [:original_application_ctx]}],
    )

    # ctx = {params: {song: nil}, slug: "0x666"}


    run_checks_pipe      = Trailblazer::Activity::Circuit::Builder::Step.InstanceMethod(:run_checks)
    title_length_ok_pipe = Trailblazer::Activity::Circuit::Builder::Step.InstanceMethod(:title_length_ok?)

    success_pipe = pipeline_circuit([:success, success = Trailblazer::Activity::Terminus::Success.new(semantic: :success), Trailblazer::Activity::Circuit::Task::Adapter::LibInterface])
    failure_pipe = pipeline_circuit([:failure, failure = Trailblazer::Activity::Terminus::Failure.new(semantic: :failure), Trailblazer::Activity::Circuit::Task::Adapter::LibInterface])

    validate_outputs = {
      success: success,
      failure: failure
    }

    validate_circuit, validate_termini_nodes = Trailblazer::Activity::Circuit::Builder.Circuit(
      [
        [:run_checks, run_checks_pipe, Trailblazer::Activity::Circuit::Processor, {}, Trailblazer::Activity::Circuit::Node::Scoped, {copy_from_outer_ctx: [:exec_context]}],
        {Trailblazer::Activity::Right => :title_length_ok?, Trailblazer::Activity::Left => :failure}
      ],
      [
        [:title_length_ok?, title_length_ok_pipe, Trailblazer::Activity::Circuit::Processor, {}, Trailblazer::Activity::Circuit::Node::Scoped, {copy_from_outer_ctx: [:exec_context]}],
        {Trailblazer::Activity::Right => :success, Trailblazer::Activity::Left => :failure}
      ],
      # FIXME: taskwrap for termini sucks.
      [
        [:success, success_pipe, Trailblazer::Activity::Circuit::Processor, {}, Trailblazer::Activity::Circuit::Node::Scoped],
      ],
      [
        [:failure, failure_pipe, Trailblazer::Activity::Circuit::Processor, {}, Trailblazer::Activity::Circuit::Node::Scoped],
      ],

      termini: [:success, :failure]
    )



    validate_tw_pipe = Trailblazer::Activity::Circuit::Builder.TaskWrap(
      [:"task_wrap.call_task", validate_circuit, Trailblazer::Activity::Circuit::Processor, {}],
    )
    # result = Trailblazer::Activity::Circuit::Processor.(
    #   validate_tw_pipe,
    #   ctx.merge(model: Object),
    #   {exec_context: io},
    #   nil,
    # )
    # raise result.inspect


    save_call_task_pipe = Trailblazer::Activity::Circuit::Builder::Step.Callable(Save)

    save_tw_pipe = Trailblazer::Activity::Circuit::Builder.TaskWrap(
      [:"task_wrap.call_task", save_call_task_pipe, Trailblazer::Activity::Circuit::Processor, {}, Trailblazer::Activity::Circuit::Node::Scoped,],
    )

    create_circuit, create_termini = Trailblazer::Activity::Circuit::Builder.Circuit(
      # [:bla, ->(ctx, lib_ctx, signal, **) { raise lib_ctx.inspect }, Trailblazer::Activity::Circuit::Task::Adapter::LibInterface, {}, Trailblazer::Activity::Circuit::Node, {}],
      [
        [:"model.task_wrap", model_tw_pipe, Trailblazer::Activity::Circuit::Processor, {exec_context: Create.new.freeze}, Trailblazer::Activity::Circuit::Node::Scoped, {copy_from_outer_ctx: []}],
        {Trailblazer::Activity::Right => :"validate.task_wrap", Trailblazer::Activity::Left => :failure}
      ], # TODO: circuit_options should be set outside of Create, in the canonical invoke.
      [
        [:"validate.task_wrap", validate_tw_pipe, Trailblazer::Activity::Circuit::Processor, {exec_context: Validate.new.freeze}, Trailblazer::Activity::Circuit::Node::Scoped, {}],
        {validate_outputs[:success] => :"save.task_wrap", validate_outputs[:failure] => :failure}
      ],
      [
        [:"save.task_wrap", save_tw_pipe, Trailblazer::Activity::Circuit::Processor, {}, Trailblazer::Activity::Circuit::Node::Scoped, {}],
        {Trailblazer::Activity::Right => :success, Trailblazer::Activity::Left => :failure}
      ], # check that we don't have circuit_options anymore here?
      # [
      #   [:success, node: Trailblazer::Activity::Terminus::Success.new(semantic: :success)],
      # ],
      # [
      #   [:failure, node: Trailblazer::Activity::Terminus::Failure.new(semantic: :failure)],
      # ],
      # FIXME: taskwrap for termini sucks. but it allows proper task wrap extending, and after all, a Terminus is a higher level concept
      [
        [:success, success_pipe, Trailblazer::Activity::Circuit::Processor, {}, Trailblazer::Activity::Circuit::Node::Scoped],
      ],
      [
        [:failure, failure_pipe, Trailblazer::Activity::Circuit::Processor, {}, Trailblazer::Activity::Circuit::Node::Scoped],
      ],

      termini: [:success, :failure]
    )

    create_outputs = validate_outputs.dup # TODO: introduce real separate signals.

    return create_circuit, create_outputs, model_input_pipe, model_output_pipe, validate_outputs, save_tw_pipe
  end
end
