module Trailblazer
  class Circuit < Struct.new(:map, :start_tuple, :termini, :nodes, keyword_init: true) # TODO: this sucks, we need to define that here.
    VERSION = "0.1.0"
  end
end
