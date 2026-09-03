require "test_helper"

class DecisionsControllerTest < ActionDispatch::IntegrationTest
  test "core loop: create a request, find it in the queue, decide it, and see the queue change" do
    post requests_url, params: { request: {
      title: "Vendor scorecards for Copperline Labs",
      organization: "Copperline Labs",
      problem_statement: "Their procurement lead compares vendors in a spreadsheet nobody else can read.",
      expected_impact: "Shared scorecards mean fewer meetings to explain a vendor choice.",
      urgency: "high"
    } }
    follow_redirect!

    created = Request.find_by!(title: "Vendor scorecards for Copperline Labs")
    assert_select "##{dom_id(created)} td", text: "Pending"
    pending_before = Request.status_counts["pending"]

    get request_url(created)
    assert_response :success
    assert_select "form[action=?]", request_decisions_path(created)

    reason = "Fits the roadmap, and two other partners asked for the same thing."
    post request_decisions_url(created), params: { decision: { decision_type: "accepted", reason: reason } }

    assert_redirected_to root_url
    follow_redirect!
    assert_select "#notice", /accepted/
    assert_select "##{dom_id(created)} td", text: "Accepted"
    assert_select "#status_counts [data-status='pending'] dd", (pending_before - 1).to_s
    assert_select "#status_counts [data-status='accepted'] dd", "1"

    created.reload
    assert created.accepted?
    assert_equal [ reason ], created.decisions.map(&:reason)
  end

  test "a decision without a reason is rejected and changes nothing" do
    request = requests(:one)

    assert_no_difference("Decision.count") do
      post request_decisions_url(request), params: { decision: { decision_type: "declined", reason: "" } }
    end

    assert_response :unprocessable_content
    assert_includes response.body, "Reason can&#39;t be blank"
    assert_select "#decision_form[data-dialog-open-value=true]", 1
    assert_equal "pending", request.reload.status
  end

  test "a decision without a type is rejected and changes nothing" do
    request = requests(:one)

    assert_no_difference("Decision.count") do
      post request_decisions_url(request), params: { decision: { reason: "Looks fine to me." } }
    end

    assert_response :unprocessable_content
    assert_includes response.body, "Decision is missing. Choose accept, defer, or decline."
    assert_equal "pending", request.reload.status
  end

  test "deciding an accepted request is rejected and changes nothing" do
    accepted = Request.create!(
      title: "Already accepted", organization: "Settled Co", problem_statement: "x", expected_impact: "y",
      urgency: "low", status: "accepted"
    )

    assert_no_difference("Decision.count") do
      post request_decisions_url(accepted), params: { decision: { decision_type: "declined", reason: "Second thoughts." } }
    end

    assert_response :unprocessable_content
    assert_includes response.body, "decisions are final"
    assert_equal "accepted", accepted.reload.status
  end

  test "a deferred request can be decided again from its page" do
    deferred = requests(:three)

    assert_difference("Decision.count", 1) do
      post request_decisions_url(deferred), params: { decision: { decision_type: "accepted", reason: "Ready now." } }
    end

    assert_redirected_to root_url
    assert_equal "accepted", deferred.reload.status

    get request_url(deferred)
    assert_select "#decision_history li", 2
    assert_equal %w[deferred accepted], css_select("#decision_history li").map { |li| li["data-decision-type"] }
    assert_select "#decision_history li:last-child", /Ready now/
    assert_select "#decision_history time[datetime]", 2
  end

  test "the decision form is shown for deferred requests and hidden for final ones" do
    get request_url(requests(:three))
    assert_select "#decision_form button", text: "Record a decision"
    assert_select "#decision_form[data-dialog-open-value=false]", 1
    assert_select "#decision_form dialog form[action=?]", request_decisions_path(requests(:three))

    accepted = Request.create!(
      title: "Already accepted", organization: "Settled Co", problem_statement: "x", expected_impact: "y",
      urgency: "low", status: "accepted"
    )
    get request_url(accepted)
    assert_select "form[action=?]", request_decisions_path(accepted), 0
  end

  test "the request page shows its decision history" do
    get request_url(requests(:three))

    assert_response :success
    assert_select "#decision_history li", 1
    assert_select "#decision_history", /Deferred/
    assert_select "#decision_history", /revisit after the dashboard rework/
  end
end
