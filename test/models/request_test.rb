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
    assert request.errors.of_kind?(:urgency, :blank)
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

  test "queue order is status, then urgency, then oldest first" do
    pending_high_newer = queued(urgency: "high", status: "pending", created_at: 1.day.from_now)
    pending_medium = queued(urgency: "medium", status: "pending", created_at: 1.day.ago)
    deferred_medium = queued(urgency: "medium", status: "deferred", created_at: 2.days.ago)
    accepted_high = queued(urgency: "high", status: "accepted", created_at: 3.days.ago)
    declined_high = queued(urgency: "high", status: "declined", created_at: 4.days.ago)

    expected = [
      requests(:one),      # pending, high, fixture timestamp
      pending_high_newer,  # pending, high, newer
      pending_medium,      # pending, medium
      requests(:two),      # pending, low
      deferred_medium,
      accepted_high,
      declined_high
    ]

    assert_equal expected.map(&:id), Request.queue_order.pluck(:id)
  end

  test "status counts cover every status in queue order with zeros filled in" do
    assert_equal({ "pending" => 2, "deferred" => 0, "accepted" => 0, "declined" => 0 }, Request.status_counts)
    assert_equal Request::STATUS_ORDER, Request.status_counts.keys

    queued(urgency: "low", status: "accepted", created_at: 1.day.ago)
    queued(urgency: "low", status: "declined", created_at: 1.day.ago)

    assert_equal({ "pending" => 2, "deferred" => 0, "accepted" => 1, "declined" => 1 }, Request.status_counts)
  end

  test "status outside the known states is a validation error, not an exception" do
    request = requests(:one).dup
    assert_nothing_raised { request.status = "approved" }
    assert_not request.valid?
    assert request.errors[:status].any?
  end

  private
    def queued(urgency:, status:, created_at:)
      Request.create!(
        title: "#{status} #{urgency} request",
        problem_statement: "Placeholder problem for ordering tests.",
        expected_impact: "Placeholder impact for ordering tests.",
        urgency: urgency,
        status: status,
        created_at: created_at
      )
    end
end
