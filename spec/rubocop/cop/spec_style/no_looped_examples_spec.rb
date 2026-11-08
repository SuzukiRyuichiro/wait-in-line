# frozen_string_literal: true

require "rubocop"
require "rubocop/rspec/support"
require_relative "../../../../lib/rubocop/cop/spec_style/no_looped_examples"

RSpec.describe RuboCop::Cop::SpecStyle::NoLoopedExamples, :config do
  include RuboCop::RSpec::ExpectOffense

  let(:config) { RuboCop::Config.new }

  it "flags `it` blocks generated inside an each loop" do
    expect_offense(<<~'RUBY')
      %w[ready seated].each do |status|
                       ^^^^ SpecStyle/NoLoopedExamples: Don't generate examples by looping with `each`. [...]
        it "is a duplicate while #{status}" do
          expect(true).to be(true)
        end
      end
    RUBY
  end

  it "flags hash tables destructured into examples" do
    expect_offense(<<~'RUBY')
      { "blank" => [""], "nil" => [nil] }.each do |label, (value)|
                                          ^^^^ SpecStyle/NoLoopedExamples: Don't generate examples by looping with `each`. [...]
        it "rejects #{label}" do
          expect(value).to be_blank
        end
      end
    RUBY
  end

  it "flags generated contexts and shared example inclusions" do
    expect_offense(<<~'RUBY')
      [1, 2].each_with_index do |n, i|
             ^^^^^^^^^^^^^^^ SpecStyle/NoLoopedExamples: Don't generate examples by looping with `each_with_index`. [...]
        context "with #{n}" do
          it_behaves_like "a thing", n
        end
      end
    RUBY
  end

  it "allows iteration inside an example body" do
    expect_no_offenses(<<~'RUBY')
      it "creates three parties" do
        3.times { create(:party) }
        %w[a b].each { |name| expect(name).to be_present }
      end
    RUBY
  end

  it "allows iteration in setup that does not define examples" do
    expect_no_offenses(<<~'RUBY')
      before do
        %w[a b].each { |name| create(:party, name: name) }
      end
    RUBY
  end
end
