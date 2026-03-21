# This is an optional feature.
module Trailblazer
  class Circuit
    # WrapRuntime is a historical term. This feature allows to, at run-time,
    # alter the currently processed node, meaning you can extend a pipeline/circuit
    # (for example to add tracing steps), or change other node attributes like the
    # processor.
    #
    # NOTE: currently, only the Adds interface is public (see Extension).
    module WrapRuntime
      # This Runner is passed via circuit_options's :runner kwarg. It extends the original
      # runner and extends pipelines throuh the configured {Extension}s.
      class Runner < Node::Runner
        def self.call(node, lib_ctx, flow_options, signal, wrap_runtime:, **circuit_options)
          node_attrs = node.to_h

          if node.task.instance_of?(Trailblazer::Circuit::Pipeline)
            node_attrs = extend_task_wrap_pipeline(wrap_runtime, node_attrs[:id], node, node_attrs)
          end

          node = node.class.new(**node_attrs)

          super
        end

        def self.extend_task_wrap_pipeline(wrap_runtime, id, node, node_attrs)
          tw_extension = wrap_runtime[id] # FIXME: this should be looked up by path, not ID.
          # FIXME: we need id here, where do we get it from?

          extended_node_attrs = tw_extension.(**node_attrs) # DISCUSS: pass runtime options here, too? # FIXME: test what we pass here.

          pp extended_node_attrs[:task].flow_map.keys

          extended_node_attrs
        end
      end
    end # WrapRuntime
  end
end
