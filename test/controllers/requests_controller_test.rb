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

    expected = [ requests(:one), pending_high_newer, pending_medium, requests(:two), requests(:three), accepted_high ]
    assert_equal expected.map { |r| dom_id(r) }, css_select("tbody tr").map { |tr| tr["id"] }
  end

  test "new form offers the three urgencies as a select" do
    get new_request_url
    assert_response :success
    assert_select "select[name='request[urgency]'] option", 4
    assert_select "input[name='request[organization]']"
  end

  test "status filter narrows the rows, marks the select, and leaves the counts global" do
    get root_url, params: { status: "deferred" }

    assert_response :success
    assert_equal [ dom_id(requests(:three)) ], css_select("tbody tr").map { |tr| tr["id"] }
    assert_select "select[name='status'] option[selected][value='deferred']"
    assert_select "#status_counts [data-status='pending'] dd", "2"
  end

  test "urgency filter keeps queue order within the subset" do
    accepted_high = queued(urgency: "high", status: "accepted", created_at: 1.day.ago)

    get root_url, params: { urgency: "high" }

    assert_equal [ dom_id(requests(:one)), dom_id(accepted_high) ], css_select("tbody tr").map { |tr| tr["id"] }
  end

  test "status and urgency filters combine" do
    get root_url, params: { status: "pending", urgency: "low" }

    assert_equal [ dom_id(requests(:two)) ], css_select("tbody tr").map { |tr| tr["id"] }
  end

  test "an unknown filter value shows the whole queue" do
    get root_url, params: { status: "bogus" }

    assert_response :success
    assert_equal Request.count, css_select("tbody tr").size
  end

  test "filter form and count links point at the queue" do
    get root_url

    assert_select "form#filters[action=?][method='get']", root_path
    assert_select "form#filters select[name='status'] option", 5
    assert_select "form#filters select[name='urgency'] option", 4
    assert_select "#status_counts a[data-status='deferred'][href=?]", root_path(status: "deferred")
  end

  test "sort control reorders the rows and marks the select" do
    get root_url, params: { sort: "submitted_desc" }

    assert_equal [ requests(:two), requests(:one), requests(:three) ].map { |r| dom_id(r) },
      css_select("tbody tr").map { |tr| tr["id"] }
    assert_select "select[name='sort'] option[selected][value='submitted_desc']"
    assert_select "a[data-controller='escape-link'][href=?]", root_path, text: "Clear"
  end

  test "sort and filter combine" do
    get root_url, params: { sort: "urgency_asc", status: "pending" }

    assert_equal [ dom_id(requests(:one)), dom_id(requests(:two)) ], css_select("tbody tr").map { |tr| tr["id"] }
  end

  test "an unknown sort falls back to queue order" do
    get root_url
    default_order = css_select("tbody tr").map { |tr| tr["id"] }

    get root_url, params: { sort: "bogus" }

    assert_response :success
    assert_equal default_order, css_select("tbody tr").map { |tr| tr["id"] }
  end

  test "count links keep the current urgency and sort" do
    get root_url, params: { urgency: "high", sort: "submitted_desc" }

    assert_select "#status_counts a[data-status='deferred'][href=?]", root_path(status: "deferred", urgency: "high", sort: "submitted_desc")
  end

  test "column header toggles cycle through ascending, descending, and no sort" do
    get root_url
    assert_select "th[data-sort='urgency']:not([aria-sort]) a[href=?]", root_path(sort: "urgency_asc")
    assert_select "th[data-sort='status'] a[href=?]", root_path(sort: "status_asc")
    assert_select "th[data-sort='submitted'] a[href=?]", root_path(sort: "submitted_asc")

    get root_url, params: { sort: "urgency_asc" }
    assert_select "th[data-sort='urgency'][aria-sort='ascending'] a[href=?]", root_path(sort: "urgency_desc")
    assert_equal [ requests(:one), requests(:three), requests(:two) ].map { |r| dom_id(r) },
      css_select("tbody tr").map { |tr| tr["id"] }

    get root_url, params: { sort: "urgency_desc" }
    assert_select "th[data-sort='urgency'][aria-sort='descending'] a[href=?]", root_path
    assert_select "th[data-sort='status']:not([aria-sort]) a[href=?]", root_path(sort: "status_asc")
  end

  test "column header toggles keep the active filters" do
    get root_url, params: { status: "pending", urgency: "high", sort: "status_desc" }

    assert_select "th[data-sort='status'] a[href=?]", root_path(status: "pending", urgency: "high")
    assert_select "th[data-sort='submitted'] a[href=?]", root_path(status: "pending", urgency: "high", sort: "submitted_asc")
  end

  test "queue rows show urgency and status as badges" do
    get root_url

    assert_select "##{dom_id(requests(:one))} [data-urgency='high']", "High"
    assert_select "##{dom_id(requests(:one))} [data-status='pending']", "Pending"
  end

  test "a filtered queue with no matches shows the empty state and a way out" do
    get root_url, params: { status: "declined" }

    assert_select "tbody tr", 0
    assert_select "#empty_state", /No requests match these filters/
    assert_select "#empty_state a[href=?]", root_path, "Clear filters"
  end

  test "an empty queue prompts for the first request" do
    Decision.delete_all
    Request.delete_all

    get root_url

    assert_select "#empty_state", /No requests yet/
    assert_select "#empty_state a[href=?]", new_request_path, "Create the first request"
    assert_select "#status_counts dd", text: "0", count: 4
  end

  test "the toolbar has a Filters button and the dialog holds the form" do
    get root_url

    assert_select "button", "Filters"
    assert_select "dialog form#filters select", 3
    assert_select "#active_filters [data-chip]", 0
  end

  test "active filters render as chips that can be removed one at a time" do
    get root_url, params: { status: "deferred", sort: "submitted_desc" }

    assert_select "#active_filters [data-chip]", 2
    assert_select "#active_filters [data-chip='status']", /Status: Deferred/
    assert_select "#active_filters [data-chip='status'] a[href=?]", root_path(sort: "submitted_desc")
    assert_select "#active_filters [data-chip='sort']", /Sort: Newest first/
    assert_select "#active_filters [data-chip='sort'] a[href=?]", root_path(status: "deferred")
    assert_select "#active_filters [data-chip='urgency']", 0
  end

  test "edit page renders the form for a pending request" do
    get edit_request_url(@sample_request)

    assert_response :success
    assert_select "input[name='request[title]'][value=?]", @sample_request.title
  end

  test "valid update changes the request and returns to its page" do
    patch request_url(@sample_request), params: { request: { title: "Bulk export, revised" } }

    assert_redirected_to request_url(@sample_request)
    follow_redirect!
    assert_select "h1", "Bulk export, revised"
    assert_select "#notice", /updated/
  end

  test "invalid update re-renders the form and changes nothing" do
    patch request_url(@sample_request), params: { request: { title: "" } }

    assert_response :unprocessable_content
    assert_includes response.body, "Title can&#39;t be blank"
    assert_equal "Bulk export for Northwind Outfitters", @sample_request.reload.title
  end

  test "update cannot change status" do
    patch request_url(@sample_request), params: { request: { title: "Still pending", status: "accepted" } }

    assert_equal "pending", @sample_request.reload.status
  end

  test "edit, update, and delete are refused once a request has been decided" do
    deferred = requests(:three)

    get edit_request_url(deferred)
    assert_redirected_to request_url(deferred)

    patch request_url(deferred), params: { request: { title: "Changed" } }
    assert_redirected_to request_url(deferred)
    follow_redirect!
    assert_select "#alert", /Only pending requests/
    assert_equal "Printable member badges for Lantern Cooperative", deferred.reload.title

    assert_no_difference("Request.count") { delete request_url(deferred) }
    assert_redirected_to request_url(deferred)
  end

  test "a pending request can be deleted" do
    assert_difference("Request.count", -1) { delete request_url(@sample_request) }

    assert_redirected_to root_url
    follow_redirect!
    assert_select "#notice", /deleted/
  end

  test "edit and delete controls appear only for pending requests" do
    get request_url(@sample_request)
    assert_select "a[href=?]", edit_request_path(@sample_request), "Edit"
    assert_select "form[action=?] button", request_path(@sample_request), "Delete"

    get request_url(requests(:three))
    assert_select "a[href=?]", edit_request_path(requests(:three)), 0
    assert_select "form[action=?] button", request_path(requests(:three)), 0
  end

  test "page 2 returns the rows after the first ten in queue order" do
    fill_two_pages

    get root_url, params: { page: 2 }

    expected = Request.sorted_by(nil).pluck(:id)[10, 10].map { |id| "request_#{id}" }
    assert_equal expected, css_select("tbody tr").map { |tr| tr["id"] }
    assert_select "#pagination", /Page 2 of 2/
    assert_select "#pagination a[rel='prev']", 1
    assert_select "#pagination a[rel='next']", 0
  end

  test "pagination links keep the active filters and sort" do
    fill_two_pages

    get root_url, params: { status: "pending", sort: "submitted_asc" }

    assert_select "#pagination a[rel='next'][href=?]", root_path(status: "pending", sort: "submitted_asc", page: 2)
  end

  test "out-of-range and junk page numbers clamp to a real page" do
    fill_two_pages

    get root_url, params: { page: 2 }
    last_page_rows = css_select("tbody tr").map { |tr| tr["id"] }

    get root_url, params: { page: 99 }
    assert_equal last_page_rows, css_select("tbody tr").map { |tr| tr["id"] }
    assert_select "#pagination", /Page 2 of 2/

    [ "abc", 0, -3 ].each do |junk|
      get root_url, params: { page: junk }
      assert_select "#pagination", /Page 1 of 2/
      assert_select "#pagination a[rel='prev']", 0
    end
  end

  test "status counts cover the whole queue on every page" do
    fill_two_pages

    get root_url, params: { page: 2 }

    assert_select "#status_counts [data-status='pending'] dd", Request.pending.count.to_s
  end

  test "no page links when everything fits, but the rows-per-page control is still there" do
    get root_url

    assert_select "#pagination", 0
    assert_select "form#per_page input[name='per_page'][value='10']"
  end

  test "rows per page can be chosen, is capped, and falls back to ten on junk" do
    fill_two_pages

    get root_url, params: { per_page: 25 }
    assert_select "tbody tr", 15
    assert_select "#pagination", 0
    assert_select "form#per_page input[name='per_page'][value='25']"

    get root_url, params: { per_page: 500 }
    assert_select "form#per_page input[name='per_page'][value='100']"
    assert_select "#status_counts a[data-status='deferred'][href=?]", root_path(per_page: 100, status: "deferred")

    get root_url, params: { per_page: 10, page: 2 }
    assert_select "#pagination a[rel='prev'][href=?]", root_path

    get root_url, params: { per_page: "abc" }
    assert_select "tbody tr", 10
    assert_select "form#per_page input[name='per_page'][value='10']"
  end

  test "rows per page travels with page, filter, and sort links" do
    fill_two_pages

    get root_url, params: { per_page: 5, status: "pending" }

    assert_select "#pagination a[rel='next'][href=?]", root_path(page: 2, per_page: 5, status: "pending")
    assert_select "#status_counts a[data-status='deferred'][href=?]", root_path(per_page: 5, status: "deferred")
    assert_select "form#per_page input[type='hidden'][name='status'][value='pending']"
    assert_select "form#filters input[type='hidden'][name='per_page'][value='5']"
  end

  test "queue shows a count for every status" do
    queued(urgency: "medium", status: "deferred", created_at: 1.day.ago)
    queued(urgency: "medium", status: "accepted", created_at: 1.day.ago)
    queued(urgency: "medium", status: "declined", created_at: 1.day.ago)
    queued(urgency: "low", status: "declined", created_at: 2.days.ago)

    get root_url

    assert_select "#status_counts [data-status='pending'] dd", "2"
    assert_select "#status_counts [data-status='deferred'] dd", "2"
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
    assert_select "tbody tr td", "Copperline Labs"
    assert_includes response.body, "Request was successfully created."
  end

  test "invalid create persists nothing and names each missing field" do
    assert_no_difference("Request.count") do
      post requests_url, params: { request: { title: "", organization: "", problem_statement: "", expected_impact: "", urgency: "" } }
    end

    assert_response :unprocessable_content
    assert_includes response.body, "This request couldn't be saved:"
    assert_includes response.body, "Title can&#39;t be blank"
    assert_includes response.body, "Organization can&#39;t be blank"
    assert_includes response.body, "Problem statement can&#39;t be blank"
    assert_includes response.body, "Expected impact can&#39;t be blank"
    assert_includes response.body, "Urgency can&#39;t be blank"
  end

  test "status cannot be set through the request form" do
    post requests_url, params: { request: valid_params.merge(status: "accepted") }

    assert_equal "pending", Request.last.status
  end

  test "the request page renders its details" do
    get request_url(@sample_request)

    assert_response :success
    assert_select "h1", @sample_request.title
    assert_select "#organization", "Northwind Outfitters"
    assert_select "#status", "Pending"
  end

  test "an unknown request returns not found" do
    get request_url(id: 0)

    assert_response :not_found
  end

  private
    # Fixtures give three rows; twelve more make two pages of ten.
    def fill_two_pages
      12.times { |n| queued(urgency: "low", status: "pending", created_at: (n + 10).days.ago) }
    end

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

    def valid_params
      {
        title: "Weekly usage digest for Copperline Labs",
        organization: "Copperline Labs",
        problem_statement: "Their account lead assembles usage numbers by hand every Monday.",
        expected_impact: "Frees a few hours a week and gives them numbers they trust.",
        urgency: "medium"
      }
    end
end
