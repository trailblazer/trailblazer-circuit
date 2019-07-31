# Activity

implements Intermediate, Implementation, compiler and `Activity::Implementation`, Activity::Interface

The `activity` gem brings a light-weight DSL to define business processes, and the runtime logic to run those activities.

A process is a set of arbitrary pieces of logic you define, chained together and put into a meaningful context by an activity. Activity lets you focus on the implementation of steps while Trailblazer takes care of the control flow.

Please find the [full documentation on the Trailblazer website](http://trailblazer.to/api-docs). [Note that the docs are WIP.]

## Example

The `activity` gem provides three default patterns to model processes: `Path`, `Railway` and `FastTrack`. Here's an example what a railway activity could look like, along with some more complex connections.

```ruby
module Memo::Update
  extend Trailblazer::Activity::Railway()
  module_function

  # here goes your business logic
  #
  def find_model(ctx, id:, **)
    ctx[:model] = Memo.find_by(id: id)
  end

  def validate(ctx, params:, **)
    return true if params[:body].is_a?(String) && params[:body].size > 10
    ctx[:errors] = "body not long enough"
    false
  end

  def save(ctx, model:, params:, **)
    model.update_attributes(params)
  end

  def log_error(ctx, params:, **)
    ctx[:log] = "Some idiot wrote #{params.inspect}"
  end

  # here comes the DSL describing the layout of the activity
  #
  step method(:find_model)
  step method(:validate), Output(:failure) => End(:validation_error)
  step method(:save)
  fail method(:log_error)
end
```

Visually, this would translate to the following circuit.

<img src="http://trailblazer.to/images/2.1/activity-readme-example.png">

You can run the activity by invoking its `call` method.

```ruby
ctx = { id: 1, params: { body: "Awesome!" } }

signal, (ctx, *) = Update.( [ctx, {}] )

pp ctx #=>
{:id=>1,
 :params=>{:body=>"Awesome!"},
 :model=>#<Memo body=nil>,
 :errors=>"body not long enough"}

pp signal #=> #<struct Trailblazer::Activity::End semantic=:validation_error>
```

With Activity, modeling business processes turns out to be ridiculously simple: You define what should happen and when, and Trailblazer makes sure _that_ it happens.

## Features

* Activities can model any process with arbitrary flow and connections.
* Nesting and compositions are allowed and encouraged.
* Different step interfaces, manual processing of DSL options, etc is all possible.
* Steps can be any kind of callable objects.
* Tracing!

## Operation

Trailblazer's [`Operation`](http://trailblazer.to/2.1/operation) internally uses an activity to model the processes.

## License

© Copyright 2018, Trailblazer GmbH

Licensed under the LGPLv3 license. We also offer a [commercial-friendly license](http://trailblazer.to/pro).
