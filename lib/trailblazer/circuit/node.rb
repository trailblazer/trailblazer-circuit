module Trailblazer
  class Circuit
    class Node < Struct.new(:task, :adapter, :options, keyword_init: true)
      def self.[](task, adapter, options: {})
        new(task: task, adapter: adapter, options: options)
      end

      module Call
        def call(ctx, flow_options, signal)
          # Note that the circuit_options are passed as keyword arguments to the Adapter.
          adapter.(task, ctx, flow_options, signal) # DISCUSS: could we pass node_processor_options to Processor.() to set a differing start task?
        end
      end

      # We need to "clone-and-update" nodes in so many places that we provide Node#merge.
      module Merge
        # Example:
        #   node.merge(options: {value: "on"})
        #
        # will merge the hash into {options}.
        def merge(options: {}, **attributes)
          properties = to_h # {task:, adapter:, options:}
          properties = properties.merge(attributes)
          # properties = properties.merge(properties_from_hash.collect { |property, value| [property, properties[property].merge(value)] }.to_h)
          properties = properties.merge(options: self.options.merge(options))

          self.class.new(**properties)
        end
      end

      include Call
      include Merge
    end
  end
end
