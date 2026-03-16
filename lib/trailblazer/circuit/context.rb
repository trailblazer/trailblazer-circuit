module Trailblazer
  class Circuit
    # Simple and fast implementation for the {lib_ctx} scoping.
    class Context
      def self.scope(outer_ctx, whitelisted_variables, variables_to_merge)
        new_ctx =
          if whitelisted_variables
            outer_ctx.slice(*whitelisted_variables) # NOTE: feel free to improve runtime performance here, see benchmark # FIXME: insert link
          else
            outer_ctx
          end

        new_ctx.merge(variables_to_merge)
      end

      def self.unscope(outer_ctx, ctx, copy_to_outer_ctx)
        new_variables = ctx.slice(*copy_to_outer_ctx)

        outer_ctx.merge(new_variables)
      end
    end
  end
end
