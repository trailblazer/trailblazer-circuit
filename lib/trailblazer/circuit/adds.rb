module Trailblazer
  class Circuit
    # Simple graph operations: insert, replace or delete
    # nodes in a {Circuit} or {Pipeline} instance.
    # Per design, this class knows internals about Circuit.
    module Adds
      module_function

      # Implements the Friendly interface™. (not so friendly anymore...)
      #
      # Since we're using this to implement {:wrap_runtime}, this has to be fast.
      # It is also used at compile-time, though.
      #
      # Feel free to benchmark and optimize this!
      def call(circuit, *instructions)
        # TODO: evaluate if we can us  https://rubyapi.org/3.4/o/array#method-i-assoc
        flow_map  = circuit.flow_map
        nodes     = circuit.nodes

        # inbound_signal: the signal from the previous node to reconnect
        instructions.each do |id, node, insertion_method, target_id, options = {inbound_signal: nil}|
          flow_map, nodes = send(insertion_method, flow_map, nodes, id, node, target_id, **options)
        end

        circuit.class.build(flow_map: flow_map, nodes: nodes) # this will recompute start and termini.
      end

      def before(flow_map, nodes, inserted_id, inserted_node, target_id, inbound_signal:, outbound_connections: nil, outbound: [[nil]])
        nodes, target_id, target_index, inserted_id, flow_ary_keys = prepare_insertion(inserted_id, inserted_node, flow_map, nodes, target_id, index_for_nil: 0)

        outbound_connections = defaultize_outbound_connections(target_id, outbound_connections: outbound_connections, outbound: outbound)

        # If not the first node, we need to update the predecessor's outgoing connection.

        if target_index > 0
          # Re-point the predecessor of target to the newly inserted.
          flow_map = reconnect_predecessor(flow_map, flow_ary_keys, target_id, inbound_signal, inserted_id)
        end

        # Since we have to ensure the correct order in flow_map, we switch
        # to array representation here for correct insertion position.
        flow_map = insert_at(flow_map, target_index, [inserted_id, outbound_connections])

        return flow_map, nodes
      end

      def after(flow_map, nodes, inserted_id, inserted_node, target_id, inbound_signal:, outbound_connections: nil, outbound: [[nil]])
        nodes, target_id, target_index, inserted_id, flow_ary_keys = prepare_insertion(inserted_id, inserted_node, flow_map, nodes, target_id, index_for_nil: -1, offset: 1)

        if target_id # this is nil when after is applied on an empty pipe.
          # outgoing connections from the target that gets a new descendent.
          target_connections = flow_map[target_id]
          original_target_descendent = target_connections[inbound_signal] # a: {Right: :b, Left: :c}

          outbound_connections = defaultize_outbound_connections(original_target_descendent, outbound: outbound, outbound_connections: outbound_connections)

          # TIL #merge reuses the old position of the key!
          flow_map = flow_map.merge(
            target_id => target_connections.merge(inbound_signal => inserted_id),
          )
        else
          outbound_connections = {} # FIXME: couldn't this case be handled via prepare_insertion and a block?
        end

        flow_map = insert_at(flow_map, target_index, [inserted_id, outbound_connections])

        return flow_map, nodes
      end

      def defaultize_outbound_connections(original_target_descendent, outbound:, outbound_connections:)
        return outbound_connections if outbound_connections

        outbound.collect do |signal_to_target_ary|
          signal, descendent = signal_to_target_ary

          signal_to_target_ary.size == 1 ? [signal, original_target_descendent] : signal_to_target_ary
        end.to_h
      end

      class IllegalIdError < Exception
      end

      def prepare_insertion(inserted_id, inserted_node, flow_map, nodes, target_id, index_for_nil:, offset: 0)
        raise IllegalIdError.new(%(ID {#{inserted_id.inspect}} already taken.)) if nodes.key?(inserted_id)

        nodes = nodes.merge(inserted_id => inserted_node) # DISCUSS: we kind of have to do that here.
        flow_ary_keys = flow_map.keys

        if target_id.nil? # new start task coming.
          target_index = index_for_nil
          target_id = flow_ary_keys[target_index]
        else
          target_index = flow_ary_keys.index(target_id) + offset
        end

        return nodes, target_id, target_index, inserted_id, flow_ary_keys
      end

      # @private
      def insert_at(flow_map, target_index, element)
        flow_ary = flow_map.to_a
        flow_ary = flow_ary.insert(target_index, element)
        flow_map = flow_ary.to_h
      end

      # @private
      def reconnect_predecessor(flow_map, flow_ary_keys, target_id, inbound_signal, new_id)
        predecessor_id, predecessor_connections = flow_map.find { |id, connections| connections[inbound_signal] == target_id }

        # First, re-point the predecessor of target to the newly inserted.
        to_merge = {predecessor_id => predecessor_connections.merge(inbound_signal => new_id)}

        return flow_map.merge(to_merge)
      end

      def delete(flow_map, nodes, _, _, target_id, inbound_signal:, **)
        nodes = nodes.slice(*(nodes.keys - [target_id]))
        flow_ary_keys = flow_map.keys
        target_index = flow_ary_keys.index(target_id) # TODO: cleanup this!

        if target_index > 0
          target_successor_id = flow_map[target_id][inbound_signal] # ID of following node.

          flow_map = reconnect_predecessor(flow_map, flow_ary_keys, target_id, inbound_signal, target_successor_id)
        end

        # flow_map = flow_map.slice(*nodes.keys) # FIXME: do we still have same order?
        flow_map = flow_map.slice(*(flow_ary_keys - [target_id]))

        return flow_map, nodes
      end

      def replace(flow_map, nodes, inserted_id, inserted_node, target_id, inbound_signal:, **)
        # Replace old key/args from nodes.
        nodes = nodes.slice(*(nodes.keys - [target_id])) # FIXME: redundant with {delete} logic.
        nodes = nodes.merge(inserted_id => inserted_node)

        flow_ary_keys = flow_map.keys
        target_index = flow_ary_keys.index(target_id) # TODO: cleanup this!

        target_connections = flow_map[target_id] # FIXME: redundant to {after} logic.

        if target_index > 0
          flow_map = reconnect_predecessor(flow_map, flow_ary_keys, target_id, inbound_signal, inserted_id)
        end

        # delete old key.
        flow_map = flow_map.slice(*(flow_ary_keys - [target_id])) # FIXME: redundant to {delete} logic.

        flow_map = insert_at(flow_map, target_index, [inserted_id, target_connections])

        return flow_map, nodes
      end
    end
  end # Circuit
end
