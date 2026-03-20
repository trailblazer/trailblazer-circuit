
module Trailblazer
  # A circuit is run using {Circuit::Processor}.
  class Circuit < Struct.new(:map, :start_tuple, :termini, :nodes, keyword_init: true)
    def self.build(flow_map:, nodes:)
      # Init logic, done when compiling Activitys and
      # when extending ciruits via :wrap_runtime.
      ids           = flow_map.keys
      start_task_id = ids[0]
      start_tuple   = [start_task_id, nodes[start_task_id]] # DISCUSS: is nodes.to_a[0] faster?
      termini       = [ids[-1]] # FIXME: test that!

      new(
        map:          flow_map,
        nodes:        nodes,
        start_tuple:  start_tuple,
        termini:      termini,
      )
    end

    # Find the next step for {current_node_id => signal}.
    # This is called in {Circuit::Processor.call}.
    def resolve(current_node_id, signal)
      return if termini.include?(current_node_id) # this is faster than any other trick I tried, with {terminus => nil} etc.

      # This lookup will always succeed unless something is entirely wrong.
      signal_map = map[current_node_id] # assumption: ID must always be a symbol.
# puts "circuit ~~~~~~ current_node_id #{current_node_id.inspect}, Signal<#{signal.inspect}> #{signal_map}"
      # return if signal_map == :terminus

      next_task_id = signal_map[signal] or raise "#{current_node_id}===>#{signal.inspect} @ #{signal_map}".inspect # this will be nil for a terminus.

      return next_task_id, nodes[next_task_id] # TODO: can we save this lookup and optimize the map directly?
    end
  end # Circuit
end
# TODO: map should be named flow_map

require "trailblazer/circuit/version"
require "trailblazer/circuit/context"
require "trailblazer/circuit/node"
require "trailblazer/circuit/node/scoped"
require "trailblazer/circuit/node/runner"
require "trailblazer/circuit/node/introspect"
require "trailblazer/circuit/pipeline"
require "trailblazer/circuit/processor"
require "trailblazer/circuit/task/adapter"
require "trailblazer/circuit/builder"
require "trailblazer/circuit/adds"
require "trailblazer/circuit/wrap_runtime/runner"
require "trailblazer/circuit/wrap_runtime/extension"
