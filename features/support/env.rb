require 'git_simple'
require_relative '../../spec/spec_helper.rb'

Before do
  Pathname('tmp').join('features').rmtree if Pathname('tmp').join('features').directory?
end
