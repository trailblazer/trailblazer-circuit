module Trailblazer
  class Circuit
    module Resolver
      # Always return the same next_node_id, and pass on the original signal.
      class Fixed < Struct.new(:next_node_id)
        def fetch(signal)
          return next_node_id, signal
        end

        def merge(element) # NOTE: experimental, needed in Adds. # DISCUSS: make it Adds:: ?
          next_node_id, _signal = element.values[0]

          Fixed.new(next_node_id) # TODO: test me
        end

        def values # NOTE: experimental, needed in Adds. # DISCUSS: make it Adds:: ?
          [[next_node_id, nil]]
        end
      end

      class Conditional < Struct.new(:known_signals, :id_for_known_signal, :id_for_else) # DISCUSS: name could be IfElse.
        def fetch(decider_signal, value = decider_signal) # DISCUSS: is that really what we want? that's in order to support value-on-signal.
          if known_signals.include?(decider_signal)
            return id_for_known_signal, value
          end

          return id_for_else, value
        end

        def merge(hsh)
          # signal, next_node_hsh = hsh.to_a[0] # DISCUSS: we're only allowing one merged signal.
          next_node_id, signal = hsh.to_a[0][1] # incoming: {Left => [:a, Left]}

          if known_signals.include?(signal)
            return self.class.new([signal], next_node_id, id_for_else)
          end

          if signal.nil?
            return self.class.new(known_signals, id_for_known_signal, next_node_id)
          end

          raise "unknown outbound signal #{signal}"
        end

        def values
          [
            *known_signals.collect { |signal| [id_for_known_signal, signal] },
            [id_for_else, nil]
          ]
        end
      end
    end # Resolver
  end
end
