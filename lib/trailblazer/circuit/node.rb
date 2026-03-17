module Trailblazer
  class Circuit
    class Node < Struct.new(:id, :task, :interface) # FIXME: why does a Node have {:merge_to_lib_ctx} ?
      def initialize(id:, task:, interface:, **)
        super(id, task, interface)
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
