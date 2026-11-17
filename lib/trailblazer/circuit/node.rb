module Trailblazer
  class Circuit
    class Node < Struct.new(:task, :adapter, :options, keyword_init: true)
      def self.[](task, adapter, options: {})
        new(task: task, adapter: adapter, options: options)
      end

      module Call
        def call(ctx, flow_options, signal, **circuit_options)
          # Note that the circuit_options are passed as keyword arguments to the Adapter.
          adapter.(task, ctx, flow_options, signal, **circuit_options) # DISCUSS: could we pass node_processor_options to Processor.() to set a differing start task?
        end
      end

      module Merge
        # node.merge(options: {value: "on"}) will merge the hash into {options}.
        def merge(**hash_properties)
          properties = to_h
          # TODO: this only works for hash properties.
          properties = properties.merge hash_properties.collect { |property, value| [property, properties[property].merge(value)] }.to_h

          self.class.new(**properties)
        end
      end

      include Call
      include Merge
    end
  end
end
