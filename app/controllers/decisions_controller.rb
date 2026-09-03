class DecisionsController < ApplicationController
  # POST /requests/1/decisions
  def create
    @request = Request.find(params.expect(:request_id))
    @decision = @request.decide(decision_type: decision_params[:decision_type], reason: decision_params[:reason])

    if @decision.persisted?
      redirect_to root_path, notice: "#{@request.title}: #{@decision.decision_type}."
    else
      render "requests/show", status: :unprocessable_content
    end
  end

  private
    def decision_params
      params.expect(decision: [ :decision_type, :reason ])
    end
end
