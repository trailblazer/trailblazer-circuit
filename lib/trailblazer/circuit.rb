module Trailblazer
  # A circuit is run using {Circuit::Processor}.
  class Circuit < Struct.new(:flow_map, :start_tuple, :nodes)
    # Automatically computes start and terminus node.
    def self.build(flow_map:, nodes:)
      ids           = flow_map.keys

      start_task_id = ids[0]
      start_tuple   = [start_task_id, nodes[start_task_id]]

      new(flow_map, start_tuple, nodes)
    end

    # Find the next step for {current_node_id => signal}.
    # This is called in {Circuit::Processor.call}.
    def resolve(current_node_id, signal)
      next_task_id = flow_map[current_node_id][signal] # TODO: how to improve dev experience for IllegalSignal?

      return next_task_id, nodes[next_task_id] # TODO: can we save this lookup and optimize the map directly?
    end
  end # Circuit
end

require "trailblazer/circuit/version"
require "trailblazer/circuit/context"
require "trailblazer/circuit/node"
require "trailblazer/circuit/node/scoped"
require "trailblazer/circuit/node/runner"
require "trailblazer/circuit/node/introspect"
require "trailblazer/circuit/node/patch"
require "trailblazer/circuit/pipeline"
require "trailblazer/circuit/processor"
require "trailblazer/circuit/task/adapter"
require "trailblazer/circuit/builder"
require "trailblazer/circuit/adds"
require "trailblazer/circuit/wrap_runtime/runner"
require "trailblazer/circuit/wrap_runtime/extension"
