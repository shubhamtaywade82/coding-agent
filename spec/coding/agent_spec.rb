# frozen_string_literal: true

RSpec.describe Coding::Agent do
  it "has a version number" do
    expect(Coding::Agent::VERSION).not_to be_nil
  end

  it "has a CLI class" do
    expect(Coding::Agent::CLI).to be_a(Class)
  end
end
