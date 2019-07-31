require "test_helper"

class DocsActivityTest < Minitest::Spec
  it do
    #:int
    Intermediate = Trailblazer::Activity::Schema::Intermediate # shortcut alias.

    intermediate = Intermediate.new(
      {
        Intermediate::TaskRef(:"Start")  => [Intermediate::Out(:success, :A)],
        Intermediate::TaskRef(:A)        => [Intermediate::Out(:success, :B),
                                             Intermediate::Out(:failure, :C)],
        Intermediate::TaskRef(:B)        => [Intermediate::Out(:success, :"End")],
        Intermediate::TaskRef(:C)        => [Intermediate::Out(:success, :B)],
        Intermediate::TaskRef(:"End", stop_event: true) => [Intermediate::Out(:success, nil)] # :)
      },
      [:"End"],   # end events
      [:"Start"], # start
    )
    #:int end


    #:impl-mod
    module Upsert
      module_function

      def a((ctx, flow_options), *)
        ctx[:seq] << :a
        return Trailblazer::Activity::Right, [ctx, flow_options]
      end

      #~mod
      extend T.def_tasks(:b, :c)
      #~mod end
    end

    start = Activity::Start.new(semantic: :default)
    _end  = Activity::End.new(semantic: :success)
    #:impl-mod end

    #:impl
    Activity = Trailblazer::Activity # shortcut alias.
    Implementation = Trailblazer::Activity::Schema::Implementation

    implementation = {
      :"Start"  => Implementation::Task(start,             [Activity::Output(Activity::Right, :success)], []),
      :A        => Implementation::Task(Upsert.method(:c), [Activity::Output(Activity::Right, :success),
                                                            Activity::Output(Activity::Left, :failure)],  []),
      :B        => Implementation::Task(Upsert.method(:c), [Activity::Output(Activity::Right, :success)], []),
      :C        => Implementation::Task(Upsert.method(:c), [Activity::Output(Activity::Right, :success)], []),
      :"End"    => Implementation::Task(_end, [Activity::Output(_end, :success)],                         []), # :)
    }
    #:impl end

    #:comp
    schema = Intermediate.(intermediate, implementation)

    activity = Activity.new(schema)
    #:comp end
  end
end
