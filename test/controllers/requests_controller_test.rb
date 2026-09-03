require "test_helper"

class RequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @sample_request = requests(:one)
  end

  test "should get index" do
    get requests_url
    assert_response :success
  end

  test "new form offers the three urgencies as a select" do
    get new_request_url
    assert_response :success
    assert_select "select[name='request[urgency]'] option", 4
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
    def valid_params
      {
        title: "Weekly usage digest for Copperline Labs",
        problem_statement: "Their account lead assembles usage numbers by hand every Monday.",
        expected_impact: "Frees a few hours a week and gives them numbers they trust.",
        urgency: "medium"
      }
    end
end
