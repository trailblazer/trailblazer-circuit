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
        def self.call(lib_ctx, flow_options, signal, wrap_runtime:, **circuit_options) # DISCUSS: always transport {:node} in {circuit_options} and remove first pos arg?
          tw_extension_set = wrap_runtime[**circuit_options] # TODO: this should be looked up by path, not ID, node, as this might apply multiple times.

          # DISCUSS: make it {#extend_circuit_options}?
          circuit_options = extend_node(tw_extension_set, **circuit_options)

          super
        end

        def self.extend_node(tw_extension_set, **circuit_options)
          return circuit_options if tw_extension_set.nil? # FIXME: make this cooler, maybe in the Resolver?
puts "@@@@@applying #{circuit_options[:id].inspect} #{circuit_options[:node___ ]}"
          circuit_options = tw_extension_set.(**circuit_options) # DISCUSS: pass runtime options here, too? # FIXME: test what we pass here.
# pp circuit_options.fetch(:node)
          pp circuit_options[:node][:task].flow_map.keys

          circuit_options
        end
      end
    end # WrapRuntime
  end
end

 # FIXME: test that we scope taskWrap
 # FIXME: lookup the runtime ext via path?
