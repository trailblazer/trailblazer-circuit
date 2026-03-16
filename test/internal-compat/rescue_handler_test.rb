require "test_helper"

# Test that we can maintain handlers with odd signatures.
class RescueHandlerTest < Minitest::Spec
  def my_rescue_handler(ctx, flow_options, *, exception:)
    ctx[:exception_class] = exception.class
    return ctx, flow_options, :Right
  end

  it "what" do
    # NOTE: this is the reason I originally started to rewrite the entire core a few months ago :D
    my_adapter_to_weird_signature = ->(user_handler, lib_ctx, flow_options, signal, **) do
      application_ctx, flow_options, signal = user_handler.(flow_options[:application_ctx], flow_options, exception: RuntimeError)

      return lib_ctx, flow_options.merge(application_ctx: application_ctx), signal
    end

    my_pipe = _A::Circuit::Builder.Pipeline(
      [:call_user_handler, method(:my_rescue_handler), my_adapter_to_weird_signature]
    )

    lib_ctx, flow_options = assert_run my_pipe, terminus: :Right, seq: []
    assert_equal lib_ctx, {}
    assert_equal flow_options, {:application_ctx=>{:seq=>[], :exception_class=>Class}}
  end
end
