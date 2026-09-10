module Trailblazer
  class Circuit
    class Node < Struct.new(:task, :interface, :options, keyword_init: true)
      def self.[](task, interface, options: {})
        new(task: task, interface: interface, options: options)
      end

      module Call
        def call(ctx, flow_options, signal, circuit_options)
          # Note that the circuit_options are passed as keyword arguments to the Adapter.
          interface.(task, ctx, flow_options, signal, **circuit_options) # DISCUSS: could we pass node_processor_options to Processor.() to set a differing start task?
        end
      end

      include Call
    end
  end
end
