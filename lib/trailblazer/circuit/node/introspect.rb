module Trailblazer
  class Circuit
    class Node
      # The Introspect API provides inflections for {Node} instances.
      module Introspect
        module_function

        def find_path(parent_node, segments)
          local_id, *segments = segments

          node = parent_node.task.nodes[local_id]

          return node if segments.empty?

          find_path(node, segments)
        end




        def find(node, path: [], &block)
          nodes = node.task.nodes

          nodes.flat_map do |id, node|
            paths = []

            if node.task.is_a?(Circuit) # recurse.
              paths += find(node, path: [*path, id], &block)
            end

            if yield(id, node)
              paths += [[[*path, id], node]]
            end

            paths
          end
        end

      end
    end
  end
end
