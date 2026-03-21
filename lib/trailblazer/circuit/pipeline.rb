module Trailblazer
  class Circuit
    # Pipeline is a Circuit which, in #resolve, simply ignores the actual signal
    # when looking up the next step.
    class Pipeline < Circuit
      def resolve(current_task_id, signal)
        next_task_id = flow_map[current_task_id][nil]

        return next_task_id, nodes[next_task_id]
      end
    end
  end # Circuit
end
