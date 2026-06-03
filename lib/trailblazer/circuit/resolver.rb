module Trailblazer
  class Circuit
    module Resolver
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
    end # Resolver
  end
end
