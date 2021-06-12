require "test_helper"

class IntrospectionTest < Minitest::Spec
  describe "Introspect::Graph" do
    let(:graph) { Activity::Introspect::Graph(nested_activity) }

    describe "#find" do
      let(:node) { graph.find(:B) }
      it { expect(node[:id]).must_equal :B }
      it { assert_outputs(node, success: Activity::Right) }
      it { expect(node[:task]).must_equal implementing.method(:b) }
      it { expect(node[:outgoings].inspect).must_equal(%{[#<struct Trailblazer::Activity::Introspect::Graph::Outgoing output=#<struct Trailblazer::Activity::Output signal=Trailblazer::Activity::Right, semantic=:success>, task=#{bc.inspect}>]}) }
      it { expect(node[:data].inspect).must_equal %{{:more=>true}} }

      describe "with Start.default" do
        let(:node) { graph.find("Start.default") }
        it { expect(node[:id]).must_equal "Start.default" }
        it { assert_outputs(node, success: Activity::Right) }
        it { expect(node[:task]).must_equal nested_activity.to_h[:circuit].to_h[:start_task] }
      end

      describe "with block" do
        let(:node) { graph.find { |node| node[:task] == implementing.method(:b) } }

        it { expect(node[:id]).must_equal :B }
        it { expect(node[:task]).must_equal implementing.method(:b) }
        it { assert_outputs(node, success: Activity::Right) }
      end
    end

    describe "#find!" do
      let(:node) { graph.find!(:B) }
      it { expect(node.class).must_equal Activity::Introspect::Graph::Node }
      it { expect(node[:id]).must_equal :B }

      it "raises exception when {:id} is invalid" do
        exception = assert_raises Activity::Introspect::Graph::NodeNotFound do
          graph.find!(:Z)
        end

        expect(exception.message).must_equal "Cannot find node with id=:Z"
      end

      it "raises exception when node is not selected via block" do
        exception = assert_raises Activity::Introspect::Graph::NodeNotFound do
          graph.find!{ |node| nil }
        end

        expect(exception.message).must_equal "Cannot find node for given block"
      end
    end

    describe "#collect" do
      it "provides 1-arg {node}" do
        nodes = graph.collect { |node| node }

        expect(nodes.size).must_equal 5

        expect(nodes[0][:task].inspect).must_equal %{#<Trailblazer::Activity::Start semantic=:default>}
        assert_outgoings nodes[0], Activity::Right => implementing.method(:b)
        expect(nodes[1][:task]).must_equal implementing.method(:b)
        assert_outgoings nodes[1], Activity::Right => bc
        expect(nodes[2][:task]).must_equal bc
        assert_outgoings nodes[2], bc.to_h[:outputs][0].signal => nodes[3].task
        expect(nodes[3][:task]).must_equal implementing.method(:f)
        assert_outgoings nodes[3], Activity::Right => nested_activity.to_h[:outputs][0].signal
        expect(nodes[4][:task].inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
        assert_outgoings nodes[4], {}
      end

      it "provides 2-arg {node, index}" do
        nodes = graph.collect { |node, i| [node, i] }

        expect(nodes.size).must_equal 5

        expect(nodes[0][0][:task].inspect).must_equal %{#<Trailblazer::Activity::Start semantic=:default>}
        expect(nodes[0][1]).must_equal 0
        expect(nodes[4][0][:task].inspect).must_equal %{#<Trailblazer::Activity::End semantic=:success>}
        expect(nodes[4][1]).must_equal 4
      end
    end

    describe "#stop_events" do
      it { expect(graph.stop_events.inspect).must_equal %{[#<Trailblazer::Activity::End semantic=:success>]} }
    end

    def assert_outputs(node, map)
      expect(Hash[
        node.outputs.collect { |out| [out.semantic, out.signal] }
      ]).must_equal(map)
    end

    def assert_outgoings(node, map)
      expect(Hash[
        node.outgoings.collect { |out| [out.output.signal, out.task] }
      ]).must_equal(map)
    end
  end
end
