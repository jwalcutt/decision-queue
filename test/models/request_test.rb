require "test_helper"

class RequestTest < ActiveSupport::TestCase
  test "fixture is valid" do
    assert requests(:one).valid?
  end

  test "title, problem statement, and expected impact are required" do
    %i[title problem_statement expected_impact].each do |field|
      request = requests(:one).dup
      request[field] = ""
      assert_not request.valid?, "#{field} should be required"
      assert request.errors.of_kind?(field, :blank), "#{field} should have a blank error"
    end
  end

  test "urgency is required" do
    request = requests(:one).dup
    request.urgency = nil
    assert_not request.valid?
    assert request.errors[:urgency].any?
  end

  test "urgency outside low, medium, high is a validation error, not an exception" do
    request = requests(:one).dup
    assert_nothing_raised { request.urgency = "critical" }
    assert_not request.valid?
    assert request.errors[:urgency].any?
  end

  test "status defaults to pending" do
    assert_equal "pending", Request.new.status
  end

  test "status outside the known states is a validation error, not an exception" do
    request = requests(:one).dup
    assert_nothing_raised { request.status = "approved" }
    assert_not request.valid?
    assert request.errors[:status].any?
  end
end
