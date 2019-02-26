require "test_helper"

class GeneratedTest < Minitest::Spec
  Inter = Trailblazer::Activity::Schema::Intermediate
  Activity = Trailblazer::Activity

  it "compiles {Schema} from intermediate and implementation, with two ends" do
    # generated by the editor or a specific DSL.
    intermediate = Inter.new({
        Inter::TaskRef(:a) => [Inter::Out(:success, :b)],
        Inter::TaskRef(:b) => [Inter::Out(:success, "End.success")],
        Inter::TaskRef("End.success", stop_event: true) => [Inter::Out(:success, nil)], # this is how the End semantic is defined.
      },
      [Inter::TaskRef("End.success"), Inter::TaskRef("End.failure")],
      [Inter::TaskRef(:a)] # start
    )

    # macro: {
    #   task: ,
    #   outputs: {}, connections: {},     # processed by DSL
    #   extensions: [], # invoked by the Schema
    # }

    # Implementation::Task(proc, outputs, extensions)


    implementation = {
      :a => Schema::Implementation::Task(implementing.method(:a), [Activity::Output(Right,       :success), Activity::Output(Left, :failure)]),
      :b => Schema::Implementation::Task(implementing.method(:b), [Activity::Output("B/success", :success), Activity::Output("B/failure", :failure)]),
      :c => Schema::Implementation::Task(implementing.method(:c), [Activity::Output(Right,       :success), Activity::Output(Left, :failure)]),
      :d => Schema::Implementation::Task(implementing.method(:d), [Activity::Output("D/success", :success), Activity::Output(Left, :failure)]),
      "End.success" => Schema::Implementation::Task(implementing::Success, [Activity::Output(implementing::Success, :success)]), # DISCUSS: End has one Output, signal is itself?
      "End.failure" => Schema::Implementation::Task(implementing::Failure, [Activity::Output(implementing::Failure, :failure)]),
    }

    # DISCUSS: basically, this is a thin DSL that calls Intermediate.(;)
    # you use this with a editor.
    mod = Module.new do
      extend Trailblazer::Activity::Generation(intermediate: intermediate)

      implement true,
        a: implementing.method(:a),
        "End.success" => implementing::Failure#, [Activity::Output(implementing::Failure, :failure)]),
    end

    # merge! ==> like inheritance without inheriting methods.

    # Manu
    # merge!(MyActivity, a: "different_method")

  end
end
