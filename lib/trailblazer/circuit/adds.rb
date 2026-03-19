module Trailblazer
  class Circuit
    # Insert, replace or delete tasks in an Activity::Circuit.
    module Adds
      # Implements the Friendly interface™. (not so friendly anymore...)
      #
      # Since we're using this to implement {:wrap_runtime}, this has to be fast.
      # It is also used at compile-time, though.
      #
      # Feel free to benchmark and optimize this!
      def self.call(circuit, *instructions)
        # TODO: evaluate if we can us  https://rubyapi.org/3.4/o/array#method-i-assoc
        blaaaaaa_FIXME = circuit.to_h
        flow_map = blaaaaaa_FIXME[:map]
        nodes = blaaaaaa_FIXME[:nodes]
        signal_to_reconnect = nil

        # Passing around start_id and last_id is for internal "caching" and part of this algorithm, not of the Circuit building.
        instructions.each do |task_args, insertion_method, target_id|
          flow_map, nodes = send(insertion_method, flow_map, nodes, task_args, target_id, signal_to_reconnect)
        end

        circuit.class.build(flow_map: flow_map, nodes: nodes) # this will recompute start and termini.
      end

      # TODO: generic Insert logic.

      def self.before(flow_map, nodes, args_for_inserted, target_id, signal_to_reconnect)
        nodes, target_id, target_index, inserted_id, flow_ary_keys = prepare_insertion(args_for_inserted, flow_map, nodes, target_id, index_for_nil: 0)

        # If not the first node, we need to update the predecessor's outgoing connection.
        if target_index > 0
          # Re-point the predecessor of target to the newly inserted.
          flow_map = reconnect_predecessor(flow_map, flow_ary_keys, target_index, signal_to_reconnect, inserted_id)
        end

        # Since we have to ensure the correct order in flow_map, we switch
        # to array representation here for correct insertion position.
        flow_map = insert_at(flow_map, target_index, [inserted_id, {signal_to_reconnect => target_id}])

        return flow_map, nodes
      end

      # raise "how does Processor compute start, how if we reached terminus? by ID or simply because there's nil?"

      def self.after(flow_map, nodes, args_for_inserted, target_id, signal_to_reconnect)
        nodes, target_id, target_index, inserted_id, flow_ary_keys = prepare_insertion(args_for_inserted, flow_map, nodes, target_id, index_for_nil: -1, offset: 1)

        target_connections = flow_map[target_id]

        # TIL #merge reuses the old position of the key!
        flow_map = flow_map.merge(
          target_id => target_connections.merge(signal_to_reconnect => inserted_id),
        )

        flow_map = insert_at(flow_map, target_index, [inserted_id, {signal_to_reconnect => target_connections[signal_to_reconnect]}])

        return flow_map, nodes
      end

      def self.prepare_insertion(args_for_inserted, flow_map, nodes, target_id, index_for_nil:, offset: 0)
        inserted_id = args_for_inserted[0]
        nodes = nodes.merge(inserted_id => args_for_inserted) # DISCUSS: we kind of have to do that here.
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
      def self.insert_at(flow_map, target_index, element)
        flow_ary = flow_map.to_a
        flow_ary = flow_ary.insert(target_index, element)
        flow_map = flow_ary.to_h
      end

      # @private
      def self.reconnect_predecessor(flow_map, flow_ary_keys, target_index, signal_to_reconnect, new_id)
        predecessor_id = flow_ary_keys[target_index - 1] # since flow_map is guaranteed to be ordered by {signal_to_reconnect}, we know that {index-1} is pointing to target.
        predecessor_connections = flow_map[predecessor_id]

        # First, re-point the predecessor of target to the newly inserted.
        to_merge = {predecessor_id => predecessor_connections.merge(signal_to_reconnect => new_id)}

        return flow_map.merge(to_merge)
      end

      def self.delete(flow_map, nodes, _, target_id, signal_to_reconnect)
        nodes = nodes.slice(*(nodes.keys - [target_id]))
        flow_ary_keys = flow_map.keys
        target_index = flow_ary_keys.index(target_id) # TODO: cleanup this!

        if target_index > 0
          target_successor_id = flow_map[target_id][signal_to_reconnect] # ID of following node.

          flow_map = reconnect_predecessor(flow_map, flow_ary_keys, target_index, signal_to_reconnect, target_successor_id)
        end

        # flow_map = flow_map.slice(*nodes.keys) # FIXME: do we still have same order?
        flow_map = flow_map.slice(*(flow_ary_keys - [target_id]))

        return flow_map, nodes
      end

      def self.replace(flow_map, nodes, args_for_inserted, target_id, signal_to_reconnect)
        inserted_id = args_for_inserted[0]

        # Replace old key/args from nodes.
        nodes = nodes.slice(*(nodes.keys - [target_id])) # FIXME: redundant with {delete} logic.
        nodes = nodes.merge(inserted_id => args_for_inserted)

        flow_ary_keys = flow_map.keys
        target_index = flow_ary_keys.index(target_id) # TODO: cleanup this!

        target_connections = flow_map[target_id] # FIXME: redundant to {after} logic.

        if target_index > 0
          flow_map = reconnect_predecessor(flow_map, flow_ary_keys, target_index, signal_to_reconnect, inserted_id)
        end

        # delete old key.
        flow_map = flow_map.slice(*(flow_ary_keys - [target_id])) # FIXME: redundant to {delete} logic.

        flow_map = insert_at(flow_map, target_index, [inserted_id, target_connections])

        return flow_map, nodes
      end
    end
  end # Circuit
end
