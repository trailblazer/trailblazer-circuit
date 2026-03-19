module Trailblazer
  class Circuit
    class Node
      # The Introspect API provides inflections for {Node} instances.
      module Introspect
        def self.find_path(parent_node, segments)
          local_id, *segments = segments

          node = parent_node.task.nodes[local_id]

          return node if segments.empty?

          find_path(node, segments)
        end
      end
    end
  end
end
