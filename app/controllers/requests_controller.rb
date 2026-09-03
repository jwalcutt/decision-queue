class RequestsController < ApplicationController
  before_action :set_request, only: %i[ show edit update destroy ]
  before_action :require_pending, only: %i[ edit update destroy ]

  # GET /requests
  def index
    @requests = Request.with_status(params[:status]).with_urgency(params[:urgency]).sorted_by(params[:sort])
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
      params.expect(request: [ :title, :problem_statement, :expected_impact, :urgency ])
    end
end
