require "test_helper"

class NestedTest < Minitest::Spec
  let(:nested) do
    Module.new do
      extend Activity::FastTrack()

      step T.def_task(:a), fast_track: true # four ends.
    end
  end

  it "connects two :plus_poles for a nested FastTrack" do
    nested = self.nested

    activity = Module.new do
      extend Activity::Path()

      task Nested(nested),
        Output(:pass_fast) => End(:my_pass_fast) # references a plus pole from VV
    end

    Cct(activity.to_h[:circuit]).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Trailblazer::Activity: {}>
#<Trailblazer::Activity: {}>
 {#<Trailblazer::Activity::End semantic=:success>} => #<End/:success>
 {#<Trailblazer::Activity::End semantic=:pass_fast>} => #<End/:my_pass_fast>
#<End/:success>

#<End/:my_pass_fast>
}
  end

  it "connects three :plus_poles for a nested FastTrack, in a Railway" do
    nested = self.nested

    activity = Module.new do
      extend Activity::Railway()

      step Nested(nested),
        Output(:pass_fast) => End(:my_pass_fast) # references a plus pole from VV
    end

    Cct(activity.to_h[:circuit]).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Trailblazer::Activity: {}>
#<Trailblazer::Activity: {}>
 {#<Trailblazer::Activity::End semantic=:success>} => #<End/:success>
 {#<Trailblazer::Activity::End semantic=:failure>} => #<End/:failure>
 {#<Trailblazer::Activity::End semantic=:pass_fast>} => #<End/:my_pass_fast>
#<End/:success>

#<End/:failure>

#<End/:my_pass_fast>
}
  end
end