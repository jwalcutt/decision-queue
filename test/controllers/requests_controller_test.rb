require "test_helper"

class RequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @sample_request = requests(:one)
  end

  test "root serves the queue" do
    get root_url
    assert_response :success
    assert_select "h1", "Decision queue"
  end

  test "queue rows render in status, urgency, and age order" do
    accepted_high = queued(urgency: "high", status: "accepted", created_at: 1.day.ago)
    pending_medium = queued(urgency: "medium", status: "pending", created_at: 1.day.ago)
    pending_high_newer = queued(urgency: "high", status: "pending", created_at: 1.day.from_now)

    get root_url

    expected = [ requests(:one), pending_high_newer, pending_medium, requests(:two), accepted_high ]
    assert_equal expected.map { |r| dom_id(r) }, css_select("tbody tr").map { |tr| tr["id"] }
  end

  test "new form offers the three urgencies as a select" do
    get new_request_url
    assert_response :success
    assert_select "select[name='request[urgency]'] option", 4
  end

  test "queue shows a count for every status" do
    queued(urgency: "medium", status: "deferred", created_at: 1.day.ago)
    queued(urgency: "medium", status: "accepted", created_at: 1.day.ago)
    queued(urgency: "medium", status: "declined", created_at: 1.day.ago)
    queued(urgency: "low", status: "declined", created_at: 2.days.ago)

    get root_url

    assert_select "#status_counts [data-status='pending'] dd", "2"
    assert_select "#status_counts [data-status='deferred'] dd", "1"
    assert_select "#status_counts [data-status='accepted'] dd", "1"
    assert_select "#status_counts [data-status='declined'] dd", "2"
  end

  test "valid create redirects to the queue and shows the new request" do
    assert_difference("Request.count", 1) do
      post requests_url, params: { request: valid_params }
    end

    assert_redirected_to requests_url
    follow_redirect!
    assert_includes response.body, "Weekly usage digest for Copperline Labs"
    assert_includes response.body, "Request was successfully created."
  end

  test "invalid create persists nothing and names each missing field" do
    assert_no_difference("Request.count") do
      post requests_url, params: { request: { title: "", problem_statement: "", expected_impact: "", urgency: "" } }
    end

    assert_response :unprocessable_content
    assert_includes response.body, "Title can&#39;t be blank"
    assert_includes response.body, "Problem statement can&#39;t be blank"
    assert_includes response.body, "Expected impact can&#39;t be blank"
    assert_includes response.body, "Urgency can&#39;t be blank"
  end

  test "status cannot be set through the request form" do
    post requests_url, params: { request: valid_params.merge(status: "accepted") }

    assert_equal "pending", Request.last.status
  end

  test "should show request" do
    get request_url(@sample_request)
    assert_response :success
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

    def valid_params
      {
        title: "Weekly usage digest for Copperline Labs",
        problem_statement: "Their account lead assembles usage numbers by hand every Monday.",
        expected_impact: "Frees a few hours a week and gives them numbers they trust.",
        urgency: "medium"
      }
    end
end
