require "test_helper"

class RequestTest < ActiveSupport::TestCase
  test "fixture is valid" do
    assert requests(:one).valid?
  end

  test "title, organization, problem statement, and expected impact are required" do
    %i[title organization problem_statement expected_impact].each do |field|
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
    assert_includes request.errors.full_messages, "Urgency must be low, medium, or high"
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

  test "sorted_by urgency orders by urgency then age regardless of status" do
    accepted_high = queued(urgency: "high", status: "accepted", created_at: 5.days.ago)
    declined_low = queued(urgency: "low", status: "declined", created_at: 1.day.ago)

    # "Ascending" urgency is high first, so the first header click gives the usual order.
    high_first = [ accepted_high, requests(:one), requests(:three), requests(:two), declined_low ]
    assert_equal high_first.map(&:id), Request.sorted_by("urgency_asc").pluck(:id)

    low_first = [ requests(:three), requests(:two), declined_low, accepted_high, requests(:one) ]
    assert_equal low_first.map(&:id), Request.sorted_by("urgency_desc").pluck(:id)
  end

  test "sorted_by status walks the states in order, oldest first within each" do
    accepted = queued(urgency: "low", status: "accepted", created_at: 5.days.ago)
    declined = queued(urgency: "high", status: "declined", created_at: 1.day.ago)

    pending_first = [ requests(:one), requests(:two), requests(:three), accepted, declined ]
    assert_equal pending_first.map(&:id), Request.sorted_by("status_asc").pluck(:id)

    declined_first = [ declined, accepted, requests(:three), requests(:one), requests(:two) ]
    assert_equal declined_first.map(&:id), Request.sorted_by("status_desc").pluck(:id)
  end

  test "sorted_by submitted orders by creation time in either direction" do
    newest = [ requests(:two), requests(:one), requests(:three) ].map(&:id)
    assert_equal newest, Request.sorted_by("submitted_desc").pluck(:id)
    assert_equal newest.reverse, Request.sorted_by("submitted_asc").pluck(:id)
  end

  test "sorted_by title and organization order alphabetically ignoring case, either direction" do
    # Lowercase title: a case-sensitive sort would put it after every capitalised fixture.
    lowercase = queued(urgency: "low", status: "pending", created_at: 1.day.ago)
    assert_equal "pending low request", lowercase.title

    a_to_z = [ requests(:one), requests(:two), lowercase, requests(:three) ]
    assert_equal a_to_z.map(&:id), Request.sorted_by("title_asc").pluck(:id)
    assert_equal a_to_z.reverse.map(&:id), Request.sorted_by("title_desc").pluck(:id)

    by_organization = [ requests(:two), requests(:three), requests(:one), lowercase ]
    assert_equal by_organization.map(&:id), Request.sorted_by("organization_asc").pluck(:id)
    assert_equal by_organization.reverse.map(&:id), Request.sorted_by("organization_desc").pluck(:id)
  end

  test "sorted_by falls back to queue order for blank or unknown sorts" do
    assert_equal Request.queue_order.pluck(:id), Request.sorted_by(nil).pluck(:id)
    assert_equal Request.queue_order.pluck(:id), Request.sorted_by("bogus").pluck(:id)
  end

  test "content can be edited while pending and is frozen once decided" do
    pending = requests(:one)
    assert pending.update(title: "Bulk export for Northwind Outfitters, revised")

    deferred = requests(:three)
    assert_not deferred.update(title: "Changed after the fact")
    assert_includes deferred.errors[:base].join, "can no longer be edited"
    assert_equal "Printable member badges for Lantern Cooperative", deferred.reload.title

    assert deferred.decide(decision_type: "accepted", reason: "Status changes still go through.").persisted?
  end

  test "a request can be deleted while pending and not once decided" do
    assert_difference("Request.count", -1) { requests(:one).destroy }

    deferred = requests(:three)
    assert_no_difference("Request.count") { assert_not deferred.destroy }
    assert_includes deferred.errors[:base].join, "can no longer be deleted"
  end

  test "with_organization filters by exact name, ignores blank, and matches nothing for an unknown name" do
    assert_equal [ requests(:two) ], Request.with_organization("Harborlight").to_a
    assert_equal Request.count, Request.with_organization("").count
    assert_equal 0, Request.with_organization("Nobody").count
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
        organization: "Placeholder Partners",
        problem_statement: "Placeholder problem for ordering tests.",
        expected_impact: "Placeholder impact for ordering tests.",
        urgency: urgency,
        status: status,
        created_at: created_at
      )
    end
end
