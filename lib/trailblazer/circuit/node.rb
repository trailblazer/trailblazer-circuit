module Trailblazer
  class Circuit
    class Node < Struct.new(:task, :interface)
      def initialize(task:, interface:, **)
        super(task, interface)
      end

      def self.[](task, interface, **)
        new(task: task, interface: interface)
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
