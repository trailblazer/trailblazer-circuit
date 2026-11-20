require "test_helper"

class FixtureTest < Minitest::Spec
  it "test fixture()" do
    _, pipe = pipe("top",
      :a,
      pipe("bc",
        :b,
        :c,
        pipe("d",
          :d),
        :e),
      :f,
      pipe("g-",
        :g,
        pipe("hi",
          :h,
          :i),),
      :j
    )

    assert_run pipe, seq: [:a, :b, :c, :d, :e, :f, :g, :h, :i, :j], terminus: Object
  end
end
