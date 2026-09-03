require "test_helper"

class DecisionTest < ActiveSupport::TestCase
  test "fixture is valid" do
    assert decisions(:deferred_three).valid?
  end

  test "reason is required" do
    decision = decisions(:deferred_three).dup
    decision.reason = ""
    assert_not decision.valid?
    assert decision.errors.of_kind?(:reason, :blank)
  end

  test "decision type is required" do
    decision = decisions(:deferred_three).dup
    decision.decision_type = nil
    assert_not decision.valid?
    assert decision.errors.of_kind?(:decision_type, :blank)
  end

  test "decision type outside accepted, deferred, declined is a validation error, not an exception" do
    decision = decisions(:deferred_three).dup
    assert_nothing_raised { decision.decision_type = "approved" }
    assert_not decision.valid?
    assert_includes decision.errors.full_messages, "Decision must be accept, defer, or decline"
  end

  test "a decision must belong to a request" do
    decision = decisions(:deferred_three).dup
    decision.request = nil
    assert_not decision.valid?
    assert decision.errors[:request].any?
  end

  test "a decision on an accepted or declined request is invalid" do
    decided = Request.create!(
      title: "Already settled", problem_statement: "x", expected_impact: "y",
      urgency: "low", status: "accepted"
    )

    decision = Decision.new(request: decided, decision_type: "declined", reason: "Changed our minds.")

    assert_not decision.valid?
    assert_includes decision.errors[:base].join, "decisions are final"
  end

  test "a decision on a deferred request is valid" do
    decision = Decision.new(request: requests(:three), decision_type: "accepted", reason: "Ready now.")

    assert decision.valid?
  end

  test "a request lists its decisions" do
    assert_includes requests(:three).decisions, decisions(:deferred_three)
  end
end
