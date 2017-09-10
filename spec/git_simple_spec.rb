require "spec_helper"

RSpec.describe GitSimple do
  it "has a version number" do
    expect(GitSimple::VERSION).not_to be nil
  end

  it "does something useful" do
    expect(false).to eq(true)
  end
end
