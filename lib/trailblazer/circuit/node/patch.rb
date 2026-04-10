module Trailblazer
  class Circuit
    class Node
      module Patch
        def self.call(node, path, adds:)
          # traverse deeper if {path}
          if path.any?
            id, *path = path

            node_for_id = Node::Introspect.find_path(node, [id])
            # circuit_for_id = node_for_id.task

            # recurse
            new_node_for_id = call(node_for_id, path, adds: adds)

            # Replace the currently traversed nested node with the patched version.
            adds = [
              [
                new_node_for_id,
                :replace, id
              ]
            ]
          end

          new_circuit = Adds.(node.task, *adds)

          node.class.new(**node.to_h, task: new_circuit) # TODO: provide API from Node.
        end
      end # Patch
    end
  end
end
