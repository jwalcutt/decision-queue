class RequestsController < ApplicationController
  PER_PAGE_DEFAULT = 10
  PER_PAGE_MAX = 100

  before_action :set_request, only: %i[ show edit update destroy ]
  before_action :require_pending, only: %i[ edit update destroy ]

  # GET /requests
  def index
    scope = Request.with_status(params[:status]).with_urgency(params[:urgency]).sorted_by(params[:sort])
    @per_page = per_page
    @page_count = [ (scope.count.to_f / @per_page).ceil, 1 ].max
    @page = params[:page].to_i.clamp(1, @page_count)
    @requests = scope.offset((@page - 1) * @per_page).limit(@per_page)
    @status_counts = Request.status_counts
  end

  # GET /requests/1
  def show
    @decision = Decision.new
  end

  # GET /requests/new
  def new
    @request = Request.new
  end

  # GET /requests/1/edit
  def edit
  end

  # POST /requests
  def create
    @request = Request.new(request_params)

    if @request.save
      redirect_to requests_path, notice: "Request was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /requests/1
  def update
    if @request.update(request_params)
      redirect_to @request, notice: "Request was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /requests/1
  def destroy
    @request.destroy!
    redirect_to root_path, notice: "Request was deleted.", status: :see_other
  end

  private
    # Blank or junk falls back to the default; anything else is capped.
    def per_page
      requested = params[:per_page].to_i
      requested.positive? ? requested.clamp(1, PER_PAGE_MAX) : PER_PAGE_DEFAULT
    end

    def set_request
      @request = Request.find(params.expect(:id))
    end

    # Once a decision exists, the text it was made against stays as it was.
    def require_pending
      return if @request.editable?

      redirect_to @request, alert: "Only pending requests can be edited or deleted.", status: :see_other
    end

    # Status is deliberately absent: it changes only through the decision flow.
    def request_params
      params.expect(request: [ :title, :organization, :problem_statement, :expected_impact, :urgency ])
    end
end
