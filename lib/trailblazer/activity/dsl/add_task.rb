class Trailblazer::Activity < Module
  module DSL
    module AddTask
      def add_task!(name, task, options, &block)
        # The beautiful thing about State.add is it doesn't mutate anything.
        # We're changing state here, on the outside, by overriding the ivars.
        # That in turn means, the only mutated entity is this module.

        _builder, adds, circuit, outputs, options = State.add( self[:builder], self[:adds], name, task, options, &block ) # this could be an extension itself.

        self[:adds] = adds
        @state = @state.put(:circuit, circuit)
        @state = @state.put(:outputs, outputs)


        task, local_options = options

        # {Extension API} call all extensions.
        local_options[:extension].collect { |ext| ext.(self, *options) } if local_options[:extension]
      end
    end
  end
end