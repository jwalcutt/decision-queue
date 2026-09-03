require "test_helper"

class RequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @sample_request = requests(:one)
  end

  test "should get index" do
    get requests_url
    assert_response :success
  end

  test "should get new" do
    get new_request_url
    assert_response :success
  end

  test "should create request" do
    assert_difference("Request.count") do
      post requests_url, params: { request: { expected_impact: @sample_request.expected_impact, problem_statement: @sample_request.problem_statement, title: @sample_request.title, urgency: @sample_request.urgency } }
    end

    assert_redirected_to request_url(Request.last)
  end

  test "should show request" do
    get request_url(@sample_request)
    assert_response :success
  end
end
