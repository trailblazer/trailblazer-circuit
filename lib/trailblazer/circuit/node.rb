module Trailblazer
  class Circuit
    class Node < Struct.new(:id, :task, :interface)
      def initialize(id:, task:, interface:, **)
        super(id, task, interface)
      end

      # DISCUSS: do we like builder code here?
      def self.[](id, task, interface)
        new(id: id, task: task, interface: interface)
      end

      module Call
        def call(ctx, flow_options, signal, **circuit_options)
          interface.(task, ctx, flow_options, signal, **circuit_options) # DISCUSS: could we pass node_processor_options to Processor.() to set a differing start task?
        end
      end

      include Call
    end
  end
end
