module Trailblazer
  class Circuit
    module Resolver
      class Fixed < Struct.new(:next_node_id)
        def fetch(_signal)
          next_node_id
        end

        def merge(element) # NOTE: experimental, needed in Adds. # DISCUSS: make it Adds:: ?
          next_node_id = element.values[0]

          Fixed.new(next_node_id) # TODO: test me
        end
      end
    end # Resolver
  end
end
