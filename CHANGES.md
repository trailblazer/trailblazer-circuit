# 0.8.3

* Use `Context.for` to create contexts.

# 0.8.2

* Fix `Present` so it works with Ruby <= 2.3.

# 0.8.1

* Remove `hirb` gem dependency.

# 0.8.0

* Separate the [DSL](https://github.com/trailblazer/trailblazer-activity-dsl-linear) from the runtime code. The latter sits in this gem.
* Separate the runtime {Activity} from its compilation, which happens through {Intermediate} (the structure) and {Implementation} (the runtime implementation) now.
* Introduce {Pipeline} which is a simpler and much fast type of activity, mostly for the taskWrap.

# 0.7.2

* When recording DSL calls, use the `object_id` as key, so cloned methods are considered as different recordings.

# 0.7.1

* Alias `Trace.call` to `Trace.invoke` for consistency.
* Allow injecting your own stack into `Trace.invoke`. This enables us to provide tracing even when there's an exception (due to, well, mutability).
* Minor changes in `Trace::Present` so that "unfinished" stacks can also be rendered.
* `Trace::Present.tree` is now private and superseded by `Present.call`.

# 0.7.0

* Remove `DSL::Helper`, "helper" methods now sit directly in the `DSL` namespace.

# 0.6.2

* Allow all `Option` types for input/output.

# 0.6.1

* Make `:input` and `:output` standard options of the DSL to create variable mappings.

# 0.6.0

* The `:task` option in `Circuit::call` is now named `:start_task` for consistency.
* Removed the `:argumenter` option for `Activity::call`. Instead, an `Activity` passes itself via the `:activity` option.
* Removed the `:extension` option. Instead, any option from the DSL that `is_a?(DSL::Extension)` will be processed in `add_task!`.
* Replace argumenters with `TaskWrap::invoke`. This simplifies the whole `call` process, and moves all initialization of args to the top.
* Added `Introspect::Graph::find`.
* Removed `Introspect::Enumerator` in favor of the `Graph` API.

# 0.5.4

* Introducing `Introspect::Enumerator` and removing `Introspect.find`. `Enumerator` contains `Enumerable` and exposes all necessary utility methods.

# 0.5.3

* In Path(), allow referencing an existing task, instead of creating an end event.
    This avoids having to use two `Output() => ..` and is much cleaner.

    ```ruby
    Path( end_id: :find_model) do .. end
    ```

# 0.5.2

* In `Path()`, we removed the `#path` method in favor of a cleaner `task` DSL method. We now use the default plus_poles `success` and `failure` everywhere for consistency. This means that a `task` has two outputs, and if you referenced `Output(:success)`, that would be only one of them. We're planning to have `pass` back which has one `success` plus_pole, only. This change makes the DSL wiring behavior much more consistent.
* Changed `TaskBuilder::Builder.()` to a function `TaskBuilder::Builder()`.

# 0.5.1

* Include all end events without outgoing connections into `Activity.outputs`. In earlier versions, we were filtering out end events without incoming connections, which reduces the number of outputs, but might not represent the desired interface of an activity.
* Add `_end` to `Railway` and `FastTrack`.
* Move `Builder::FastTrack::PassFast` and `:::FailFast` to `Activity::FastTrack` since those are signals and unrelated to builders.

# 0.5.0

* Rename `Nested()` to `Subprocess` and move the original one to the `operation` gem.
* Add merging: `Activity.merge!` now allows to compose an activity by merging another.
* Enforce using `Output(..) => Track(:success)` instead of just the track color `:success`. This allow having IDs both symbols and strings.

# 0.4.3

* Make `:outputs` the canonical way to define outputs, and not `:plus_poles`. The latter is computed by the DSL if not passed.
* Allow injecting `inspect` implementations into `Introspect` methods.
* Add `Nested`.
* Add `TaskBuilder::Task#to_s`.

# 0.4.2

* `End` is not a `Struct` so we can maintain more state, and are immutable.

# 0.4.1

* Remove `decompose` and replace it with a better `to_h`.
* `End` doesn't have a redundant `@name` anymore but only a semantic.

# 0.4.0

* We now use the "Module Subclass" pattern, and activities aren't classes anymore but modules.

# 0.3.2

* In the `TaskWrap`, rename `:result_direction` to `:return_signal` and `:result_args` to `:return_args`,

# 0.3.1

* Allow passing a `:normalizer` to the DSL.
* Builders don't have to provide `keywords` as we can filter them automatically.

# 0.2.2

* Remove `Activity#end_events`.

# 0.2.1

* Restructure all `Wrap`-specific tasks.
* Remove `Hash::Immutable`, we will use the `hamster` gem instead.

# 0.2.0

* The `Activity#call` API is now

    ```ruby
    signal, options, _ignored_circuit_options = Activity.( options, **circuit_options )
    ```

    The third return value, which is typically the `circuit_options`, is _ignored_ and for all task calls in this `Activity`, an identical, unchangeable set of `circuit_options` is passed to. This dramatically reduces unintended behavior with the task_wrap, tracing, etc. and usually simplifies tasks.

    The new API allows using bare `Activity` instances as tasks without any clumsy nesting work, making nesting very simple.

    A typical task will look as follows.

    ```ruby
    ->( (options, flow_options), **circuit_args ) do
      [ signal, [options, flow_options], *this_will_be_ignored ]
    end
    ```

    A task can only emit a signal and "options" (whatever data structure that may be), and can *not* change the `circuit_options` which usually contain activity-wide "global" configuration.



# 0.1.6

* `Nested` now is `Subprocess` because it literally does nothing else but calling a _process_ (or activity).

# 0.1.5

# 0.1.4

* `Nested` now uses kw args for `start_at` and the new `call` option. The latter allows to set the called method on the nested activity, e.g. `__call`.

# 0.1.3

* Introduce `Activity#outputs` and ditch `#end_events`.

# 0.1.2

* Consistent return values for all graph operations: `node, edge`.
* `Edge` now always gets an id.
* `#connect_for!` always throws away the old edge, fixing a bug where graph and circuit would look different.
* Internal simplifications for `Graph` alteration methods.

# 0.1.1

* Fix loading order.

# 0.0.12

* In `Activity::Before`, allow specifying what predecessing tasks to connect to the new_task via the
`:predecessors` option, and without knowing the direction. This will be the new preferred style in `Trailblazer:::Sequence`
where we can always assume directions are limited to `Right` and `Left` (e.g., with nested activities, this changes to a
colorful selection of directions).

# 0.0.11

* Temporarily allow injecting a `to_hash` transformer into a `ContainerChain`. This allows to ignore
certain container types such as `Dry::Container` in the KW transformation. Note that this is a temp
fix and will be replaced with proper pattern matching.

# 0.0.10

* Introduce `Context::ContainerChain` to eventually replace the heavy-weight `Skill` object.
* Fix a bug in `Option` where wrong args were passed when used without `flow_options`.

# 0.0.9

* Fix `Context#[]`, it returned `nil` when it should return `false`.

# 0.0.8

* Make `Trailblazer::Option` and `Trailblazer::Option::KW` a mix of lambda and object so it's easily extendable.

# 0.0.7

* It is now `Trailblazer::Args`.

# 0.0.6

* `Wrapped` is now `Wrap`. Also, a consistent `Alterations` interface allows tweaking here.

# 0.0.5

* The `Wrapped::Runner` now applies `Alterations` to each task's `Circuit`. This means you can inject `:task_alterations` into `Circuit#call`, which will then be merged into the task's original circuit, and then run. While this might sound like crazy talk, this allows any kind of external injection (tracing, input/output contracts, step dependency injections, ...) for specific or all tasks of any circuit.

# 0.0.4

* Simpler tracing with `Stack`.
* Added `Context`.
* Simplified `Circuit#call`.

# 0.0.3

* Make the first argument to `#Activity` (`@name`) always a Hash where `:id` is a reserved key for the name of the circuit.

# 0.0.2

* Make `flow_options` an immutable data structure just as `options`. It now needs to be returned from a `#call`.

# 0.0.1

* First release into an unsuspecting world. 🚀
