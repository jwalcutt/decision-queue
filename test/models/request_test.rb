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
      requests(:three),    # deferred, low
      accepted_high,
      declined_high
    ]

    assert_equal expected.map(&:id), Request.queue_order.pluck(:id)
  end

  test "status counts cover every status in queue order with zeros filled in" do
    assert_equal({ "pending" => 2, "deferred" => 1, "accepted" => 0, "declined" => 0 }, Request.status_counts)
    assert_equal Request::STATUS_ORDER, Request.status_counts.keys

    queued(urgency: "low", status: "accepted", created_at: 1.day.ago)
    queued(urgency: "low", status: "declined", created_at: 1.day.ago)

    assert_equal({ "pending" => 2, "deferred" => 1, "accepted" => 1, "declined" => 1 }, Request.status_counts)
  end

  test "decide records the decision and moves the request to that state" do
    request = requests(:one)

    decision = request.decide(decision_type: "declined", reason: "Out of scope for this quarter.")

    assert decision.persisted?
    assert_equal "declined", request.reload.status
    assert_equal [ decision ], request.decisions.to_a
  end

  test "decide with a blank reason saves nothing and leaves the status alone" do
    request = requests(:one)

    decision = nil
    assert_no_difference("Decision.count") do
      decision = request.decide(decision_type: "accepted", reason: "")
    end

    assert_not decision.persisted?
    assert decision.errors.of_kind?(:reason, :blank)
    assert_equal "pending", request.reload.status
  end

  test "pending and deferred requests are decidable, accepted and declined are not" do
    assert requests(:one).decidable?
    assert requests(:three).decidable?
    assert_not queued(urgency: "low", status: "accepted", created_at: 1.day.ago).decidable?
    assert_not queued(urgency: "low", status: "declined", created_at: 1.day.ago).decidable?
  end

  test "accepted and declined requests cannot be decided again" do
    %w[accepted declined].each do |terminal|
      request = queued(urgency: "low", status: terminal, created_at: 1.day.ago)

      decision = nil
      assert_no_difference("Decision.count") do
        decision = request.decide(decision_type: "deferred", reason: "Second thoughts.")
      end

      assert_not decision.persisted?
      assert_includes decision.errors[:base].join, "decisions are final"
      assert_equal terminal, request.reload.status
    end
  end

  test "a deferred request can be decided again and keeps its history" do
    request = requests(:three)

    decision = request.decide(decision_type: "accepted", reason: "The dashboard rework shipped; this is next.")

    assert decision.persisted?
    assert_equal "accepted", request.reload.status
    assert_equal %w[deferred accepted], request.decisions.map(&:decision_type)
  end

  test "the decision and the status change succeed or fail together" do
    request = requests(:one)
    request.define_singleton_method(:update!) { |*| raise ActiveRecord::RecordInvalid }

    assert_no_difference("Decision.count") do
      assert_raises(ActiveRecord::RecordInvalid) do
        request.decide(decision_type: "accepted", reason: "Should roll back.")
      end
    end

    assert_equal "pending", request.reload.status
  end

  test "with_status filters by a known status and ignores blank or unknown values" do
    assert_equal [ requests(:three) ], Request.with_status("deferred").to_a
    assert_equal Request.count, Request.with_status(nil).count
    assert_equal Request.count, Request.with_status("bogus").count
  end

  test "with_urgency filters by a known urgency and ignores blank or unknown values" do
    assert_equal [ requests(:one) ], Request.with_urgency("high").to_a
    assert_equal Request.count, Request.with_urgency("").count
    assert_equal Request.count, Request.with_urgency("critical").count
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
