module Trailblazer
  class Circuit
    class Node
      module Patch
        def self.call(node, path, adds:, processor_for_adds: Circuit::Adds) # the {:adds} is the user's patch.
          # traverse deeper if {path}
          if path.any?
            id, *path = path

            node_for_id = Node::Introspect.find_path(node, Array(id)) # this always has to point to a "Circuit" or anything that likes Adds.

            # recurse
            new_node_for_id = call(node_for_id, path, adds: adds, processor_for_adds: processor_for_adds)

            # Replace the currently traversed nested node with the patched version.
            adds = [
              [
                id,
                new_node_for_id,
                :replace, id
              ]
            ]
          end

          new_circuit = processor_for_adds.(node.task, *adds) # normally, this translates to {Adds.(node.task, *adds)}.

          # Since ADDS is on Circuit-level, we have to create the Node ourselves.
          node.merge(task: new_circuit)
        end
      end # Patch
    end
  end
end
