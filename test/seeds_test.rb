require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  test "seeds load 56 requests with matching decisions and are safe to run twice" do
    before = Request.pluck(:id)

    assert_difference("Request.count", 56) do
      assert_difference("Decision.count", 28) { Rails.application.load_seed }
    end

    assert_no_difference([ "Request.count", "Decision.count" ]) { Rails.application.load_seed }

    Request.where.not(id: before).where.not(status: "pending").find_each do |request|
      assert_equal [ request.status ], request.decisions.map(&:decision_type), request.title
    end
  end
end
