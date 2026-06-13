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
      def call(circuit, *instructions) # DISCUSS: should we allow {:outbound_signal} here?
        # TODO: evaluate if we can us  https://rubyapi.org/3.4/o/array#method-i-assoc
        flow_map  = circuit.flow_map
        nodes     = circuit.nodes

        # inbound_signal: the signal from the previous node to reconnect
        instructions.each do |id, node, insertion_method, target_id, options = {outbound_signal: nil}|
          flow_map, nodes = send(insertion_method, flow_map, nodes, id, node, target_id, **options)
        end

        circuit.class.build(flow_map: flow_map, nodes: nodes) # this will recompute start and termini.
      end

      DEFAULT_HASH_RESOLVER_BUILDER = Class.new do # DISCUSS: do we need/want this anywhere?
        def self.call(target_id, outbound_signal:, **)
          {outbound_signal => [target_id, outbound_signal]}
        end
      end

      DEFAULT_RESOLVER_BUILDER = Class.new do
        def self.call(target_id, **)
          Resolver::Fixed.new(target_id)
        end
      end

      def before(flow_map, nodes, inserted_id, inserted_node, target_id, **options)
        if flow_map.size == 0
          return after(flow_map, nodes, inserted_id, inserted_node, target_id, **options)
        end

        if target_id.nil?
          target_id = flow_map.keys.first # DISCUSS: this obviously only works correctly in "pipes".
        end

        # translate before to after.
        target_index = find_insert_at_index(flow_map, target_id, offset: 0)

        # Add a (new?) first element.
        # We cannot use #after for that, so we gotta do it ourselves.
        if target_index == 0
          return insert_node_at(flow_map, nodes, inserted_id, inserted_node, target_id, 0, options, **options) # downstream-only.
        end

        # In :before, we take the literal "before" node (index - 1) and insert the new node {after}.
        # A more elaborate way would be to find the first node that has an outgoing {inbound_signal} that targets "us".
        target_id = flow_map.keys[target_index - 1] # FIXME: spreading knowledge about flow_map everywhere.

        after(flow_map, nodes, inserted_id, inserted_node, target_id, **options)
      end

      def find_insert_at_index(flow_map, target_id, offset:)
        flow_map.keys.index(target_id) + offset
      end

      # Place a new "node" on a connection by reconnecting the predecessor and then connecting new to "target".
      def insert_with_predecessor(flow_map, nodes, inserted_id, inserted_node, insert_at_index, inbound_signal: nil, predecessor_id: nil, **options_for_resolver_builder)
        # we're not the very first element, so
        # reconnect the {predecessor --inbound_signal--> new_node}.
        predecessor_resolver = flow_map[predecessor_id]
        signal_from_predecessor = inbound_signal

        # find out where the predecessor orginally pointed to via inbound_signal,
        # as that's the signal we're repointing.
        successor_id, _ = predecessor_resolver.fetch(inbound_signal)

        # Re-point the predecessor of target to the newly inserted.
        flow_map = reconnect_predecessor(flow_map, inserted_id, predecessor_id, predecessor_resolver, signal_from_predecessor)

        flow_map, nodes = insert_node_at(flow_map, nodes, inserted_id, inserted_node, successor_id, insert_at_index, options_for_resolver_builder, **options_for_resolver_builder)

        return flow_map, nodes
      end

      # Only knows about downstream/outbound concepts.
      def insert_node_at(flow_map, nodes, inserted_id, inserted_node, successor_id, insert_at_index, options_for_resolver_builder, resolver: build_resolver(successor_id, **options_for_resolver_builder), **)
        nodes    = add_node(nodes, inserted_id, inserted_node)
        flow_map = insert_at(flow_map, insert_at_index, [inserted_id, resolver])

        return flow_map, nodes
      end

      # #merge, #values

      # DISCUSS: {inbound_signal} is refering to the signal going into the new descendent?
      def after(flow_map, nodes, inserted_id, inserted_node, target_id, **options)
        if flow_map.size == 0
          # TODO: check target_id, it must be nil!
          # TODO: test if outbound_signal is passed through.
          return insert_node_at(flow_map, nodes, inserted_id, inserted_node, nil, 0, options, **options) # downstream-only.
        end

        if target_id.nil?
          target_id = flow_map.keys.last # DISCUSS: this obviously only works correctly in "pipes".
        end

        # find node after {target_id}.
        insert_at_index = find_insert_at_index(flow_map, target_id, offset: 1)

        # You always have a predecessor with {:after} unless it's an empty pipe.
        insert_with_predecessor(flow_map, nodes, inserted_id, inserted_node, insert_at_index, predecessor_id: target_id, **options)
      end

      class IllegalIdError < Exception
      end

      def add_node(nodes, inserted_id, inserted_node)
        raise IllegalIdError.new(%(ID {#{inserted_id.inspect}} already taken.)) if nodes.key?(inserted_id)

        nodes = nodes.merge(inserted_id => inserted_node) # DISCUSS: we kind of have to do that here.
      end

      def build_resolver(target_id, resolver_builder: DEFAULT_RESOLVER_BUILDER, **options)
        resolver_builder.(target_id, **options) # outbound_connections.
      end

      # @private
      def insert_at(flow_map, target_index, element)
        flow_ary = flow_map.to_a
        flow_ary = flow_ary.insert(target_index, element)
        flow_map = flow_ary.to_h
      end

      # @private
      def reconnect_predecessor(flow_map, new_id, predecessor_id, predecessor_resolver, signal_from_predecessor)
        # Re-point the predecessor of target to the newly inserted.
        to_merge = {predecessor_id => predecessor_resolver.merge(signal_from_predecessor => [new_id, signal_from_predecessor])}

        return flow_map.merge(to_merge)
      end

      # TODO: this could be the predecessor search algorithm for {:before}
      # def find_predecessor_with_signal(flow_map, target_id, signal_from_predecessor = nil)
      #   flow_map.find { |id, resolver|
      #     resolver.values.find { |next_node_id, signal|
      #       if [next_node_id, signal] == [target_id, signal_from_predecessor]
      #         return id, resolver, signal
      #       end
      #     }
      #   }
      # end

      def delete(flow_map, nodes, _, _, target_id, inbound_signal:, **)
        nodes = nodes.slice(*(nodes.keys - [target_id]))
        flow_ary_keys = flow_map.keys
        target_index = flow_ary_keys.index(target_id) # TODO: cleanup this!

        if target_index > 0
          target_successor_id = flow_map[target_id].fetch(inbound_signal) # ID of following node.

          flow_map = reconnect_predecessor(flow_map, flow_ary_keys, target_id, inbound_signal, target_successor_id)
        end

        # flow_map = flow_map.slice(*nodes.keys) # FIXME: do we still have same order?
        flow_map = flow_map.slice(*(flow_ary_keys - [target_id]))

        return flow_map, nodes
      end

      def replace(flow_map, nodes, inserted_id, inserted_node, target_id, reuse_resolver: true, **options)
        predecessors_with_signal = find_predecessors(flow_map, target_id)

        flow_map_updates = predecessors_with_signal.collect do |id, resolver, signal_to_target|
          [id, resolver.merge(signal_to_target => [inserted_id, signal_to_target])]
        end.to_h

        # all predecessors of (target_id) now point to the new node.
        flow_map = flow_map.merge(flow_map_updates) # #merge preserves positions. # TODO: test!

        if reuse_resolver # TODO: allow your own resolver (where do we need that?).
          resolver_from_target = flow_map.fetch(target_id)
        end

        insert_at_index = find_insert_at_index(flow_map, target_id, offset: 0)
        flow_map, nodes = insert_node_at(flow_map, nodes, inserted_id, inserted_node, target_id, insert_at_index, {}, resolver: resolver_from_target)

        # delete old key.
        flow_map = flow_map.slice(*(flow_map.keys - [target_id])) # FIXME: redundant to {delete} logic.
        nodes    = nodes.slice(*(nodes.keys - [target_id])) # FIXME: redundant with {delete} logic.

        return flow_map, nodes
      end

      def find_predecessors(flow_map, target_id)
        flow_map.flat_map { |id, resolver|
          resolver.values.collect { |successor_id, signal|
            successor_id == target_id ? [id, resolver, signal] : nil
          }
        }.compact
      end
    end
  end # Circuit
end
