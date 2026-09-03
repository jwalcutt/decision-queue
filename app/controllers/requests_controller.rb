class RequestsController < ApplicationController
  before_action :set_request, only: %i[ show ]

  # GET /requests
  def index
    @requests = Request.queue_order
    @status_counts = Request.status_counts
  end

  # GET /requests/1
  def show
  end

  # GET /requests/new
  def new
    @request = Request.new
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

  private
    def set_request
      @request = Request.find(params.expect(:id))
    end

    # Status is deliberately absent: it changes only through the decision flow.
    def request_params
      params.expect(request: [ :title, :problem_statement, :expected_impact, :urgency ])
    end
end
