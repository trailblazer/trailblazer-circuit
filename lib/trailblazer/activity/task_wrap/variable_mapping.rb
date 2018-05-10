require "trailblazer/context"

class Trailblazer::Activity < Module
  module TaskWrap

    module VariableMapping
      # DSL step for Magnetic::Normalizer.
      # Translates `:input` and `:output` into VariableMapping taskWrap extensions.
      def self.normalizer_step_for_input_output(ctx, *)
        options, io_config = Magnetic::Options.normalize( ctx[:options], [:input, :output] )

        return true if io_config.empty?

        ctx[:options] = options # without :input and :output
        ctx[:options] = options.merge(Trailblazer::Activity::TaskWrap::VariableMapping(io_config) => true)
      end
    end

    # @private
    def self.filter_for(filter)
      if filter.is_a?(Proc)
        filter
      else
        TaskWrap::Input::filter_from_dsl(filter)
      end
    end

    def self.VariableMapping(input:, output:)
      input  = filter_for(input)

      input  = Input.new(
                Input::Scoped.new(
                  Trailblazer::Option::KW( input ) ) )

      output = filter_for(output)

      output = Output.new(
                Output::Unscoped.new(
                  Trailblazer::Option::KW( output ) ) )

      Trailblazer::Activity::DSL::Extension.new(
        Merge.new(
          Module.new do
            extend Path::Plan()

            task input,  id: "task_wrap.input", before: "task_wrap.call_task"
            task output, id: "task_wrap.output", before: "End.success", group: :end
          end
        )
      )
    end

    # TaskWrap step to compute the incoming {Context} for the wrapped task.
    # This allows renaming, filtering, hiding, of the options passed into the wrapped task.
    #
    # Both Input and Output are typically to be added before and after task_wrap.call_task.
    #
    # @note Assumption: we always have :input _and_ :output, where :input produces a Context and :output decomposes it.
    class Input
      def initialize(filter)
        @filter = filter
      end

      # `original_args` are the actual args passed to the wrapped task: [ [options, ..], circuit_options ]
      #
      def call( (wrap_ctx, original_args), circuit_options )
        # let user compute new ctx for the wrapped task.
        input_ctx = apply_filter(*original_args) # FIXME: THIS SHOULD ALWAYS BE A _NEW_ Context.

        wrap_ctx = wrap_ctx.merge( vm_original_ctx: original_args[0][0] ) # remember the original ctx

        # decompose the original_args since we want to modify them.
        (original_ctx, original_flow_options), original_circuit_options = original_args

        # instead of the original Context, pass on the filtered `input_ctx` in the wrap.
        return Trailblazer::Activity::Right, [ wrap_ctx, [[input_ctx, original_flow_options], original_circuit_options] ]
      end

      private

      def apply_filter((ctx, original_flow_options), original_circuit_options)
        new_ctx = @filter.( ctx, original_circuit_options )
        raise new_ctx.inspect unless new_ctx.is_a?(Trailblazer::Context)
        new_ctx
      end

      class Scoped
        def initialize(filter)
          @filter = filter
        end

        def call(original_ctx, circuit_options)
          Trailblazer::Context(
            @filter.(original_ctx, **circuit_options)
          )
        end
      end

      # The returned filter compiles a new hash for Scoped/Unscoped that only contains
      # the desired i/o variables.
      def self.filter_from_dsl(map)
        hsh = DSL.hash_for(map)

        ->(incoming_ctx, kwargs) { Hash[hsh.collect { |from_name, to_name| [to_name, incoming_ctx[from_name]] }] }
      end

    end

    module DSL
      def self.hash_for(ary)
        return ary if ary.instance_of?(::Hash)
        Hash[ary.collect { |name| [name, name] }]
      end
    end

    # TaskWrap step to compute the outgoing {Context} from the wrapped task.
    # This allows renaming, filtering, hiding, of the options returned from the wrapped task.
    class Output
      def initialize(filter)
        @filter   = filter
      end

      # Runs the user filter and replaces the ctx in `wrap_ctx[:return_args]` with the filtered one.
      def call( (wrap_ctx, original_args), **circuit_options )
        (original_ctx, original_flow_options), original_circuit_options = original_args

        returned_ctx, _ = wrap_ctx[:return_args] # this is the Context returned from `call`ing the task.
        original_ctx    = wrap_ctx[:vm_original_ctx]

        # let user compute the output.
        output_ctx = @filter.(original_ctx, returned_ctx, **original_circuit_options)

        wrap_ctx = wrap_ctx.merge( return_args: [output_ctx, original_flow_options] )

        # and then pass on the "new" context.
        return Trailblazer::Activity::Right, [ wrap_ctx, original_args ]
      end

      private

      # Merge the resulting {@filter.()} hash back into the original ctx.
      # DISCUSS: do we need the original_ctx as a filter argument?
      class Unscoped
        def initialize(filter)
          @filter = filter
        end

        def call(original_ctx, new_ctx, **circuit_options)
          original_ctx.merge(
            @filter.(new_ctx, **circuit_options)
          )
        end
      end
    end
  end # Wrap
end