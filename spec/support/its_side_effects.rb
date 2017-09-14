module RSpec
  module ItsSideEffects
    def its_side_effects_are(*options, &block)
      its_caller = caller.reject { |file_line| file_line =~ /its_side_effects/ }
      describe('side effects', caller: its_caller) do
        before { subject } # rubocop:disable RSpec/NamedSubject
        example(nil, *options, &block)
      end
    end

    alias has_side_effects its_side_effects_are
    alias specify_side_effects its_side_effects_are
  end
end

RSpec.configure do |rspec|
  rspec.extend RSpec::ItsSideEffects
  rspec.backtrace_exclusion_patterns << /its_side_effects/
end
