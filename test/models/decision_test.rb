require "test_helper"

class DecisionTest < ActiveSupport::TestCase
  test "fixture is valid" do
    assert decisions(:deferred_two).valid?
  end

  test "reason is required" do
    decision = decisions(:deferred_two).dup
    decision.reason = ""
    assert_not decision.valid?
    assert decision.errors.of_kind?(:reason, :blank)
  end

  test "decision type is required" do
    decision = decisions(:deferred_two).dup
    decision.decision_type = nil
    assert_not decision.valid?
    assert decision.errors.of_kind?(:decision_type, :blank)
  end

  test "decision type outside accepted, deferred, declined is a validation error, not an exception" do
    decision = decisions(:deferred_two).dup
    assert_nothing_raised { decision.decision_type = "approved" }
    assert_not decision.valid?
    assert decision.errors[:decision_type].any?
  end

  test "a decision must belong to a request" do
    decision = decisions(:deferred_two).dup
    decision.request = nil
    assert_not decision.valid?
    assert decision.errors[:request].any?
  end

  test "a request lists its decisions" do
    assert_includes requests(:two).decisions, decisions(:deferred_two)
  end
end
