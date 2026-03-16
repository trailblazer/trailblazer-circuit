module Trailblazer
  class Circuit
    class Node < Struct.new(:id, :task, :interface, :merge_to_lib_ctx, :copy_from_outer_ctx, :copy_to_outer_ctx, :return_outer_signal, keyword_init: true) # FIXME: why does a Node have {:merge_to_lib_ctx} ?
      def call(ctx, flow_options, signal, **circuit_options)
        interface.(task, ctx, flow_options, signal, **circuit_options) # DISCUSS: could we pass node_processor_options to Processor.() to set a differing start task?
      end
    end
  end
end
