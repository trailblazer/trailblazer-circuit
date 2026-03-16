require 'memory_profiler'

  # class Step < Struct.new(:write_name, :circuit)
  #   def a()
  #     return true
  #   end

  #   def b()
  #     return true, 1
  #   end

  #   def c
  #     return :c
  #   end
  # end

  class Step < Struct.new(:write_name)
    def a()
      return write_name
    end

    def b()
      return true, 1
    end

    def c
      return :c
    end
  end

ary = []

report = MemoryProfiler.report  do
  # Your code here

  (1..10).each do |i|
    data_behavior = Step.new(i.to_s)
    circuit = {
      data_behavior.method(:a) => 1,
      data_behavior.method(:b) => 1,
      data_behavior.method(:c) => 1,
    }

    ary << circuit
  end

end

report.pretty_print

# Total allocated: 4800 bytes (60 objects)
# allocated memory by class
# -----------------------------------
#       2400  Method
#       1760  Hash
#        400  Step
#        400  String

# allocated objects by class
# -----------------------------------
#         30  Method
#         11  Hash
#         10  Step
#         10  String

# Learning:
##
# we create an instance that keeps a certain configuration (eg write_name: :current_user).
# in the circuit, we then reference the method of that very object, which seems super clever (it is!)
# but it uses shit-tons of memory because every method reference is a separate object.



ary_2 = []

report = MemoryProfiler.report  do
  # Your code here

  (1..10).each do |i|
    data_behavior = Step.new(i.to_s)
    circuit = {
      :a => 1,
      :b => 1,
      :c => 1,
    }

    ary_2 << [circuit, data_behavior]
  end

end

report.pretty_print
# Total allocated: 2800 bytes (40 objects)

# allocated memory by class
# -----------------------------------
#       1600  Hash
#        400  Array
#        400  Step
#        400  String
