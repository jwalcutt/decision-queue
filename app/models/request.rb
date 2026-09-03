class Request < ApplicationRecord
  has_many :decisions, -> { order(:created_at) }, dependent: :destroy

  STATUS_ORDER = %w[pending deferred accepted declined].freeze
  URGENCY_ORDER = %w[high medium low].freeze

  enum :urgency, { low: "low", medium: "medium", high: "high" }, validate: { allow_nil: true }
  enum :status, { pending: "pending", accepted: "accepted", deferred: "deferred", declined: "declined" },
    default: :pending, validate: true

  validates :title, :problem_statement, :expected_impact, :urgency, presence: true

  # Counts for every status in queue order, zeros included, from one GROUP BY.
  def self.status_counts
    counts = group(:status).count
    STATUS_ORDER.index_with { |status| counts.fetch(status, 0) }
  end

  # Queue order: still-actionable statuses first, then urgency, then oldest first.
  scope :queue_order, -> {
    in_order_of(:status, STATUS_ORDER, filter: false)
      .in_order_of(:urgency, URGENCY_ORDER, filter: false)
      .order(:created_at)
  }

  # Records a decision and moves the request to that state, or does neither.
  # Always returns the decision; an unsaved one carries the validation errors.
  def decide(decision_type:, reason:)
    decision = Decision.new(request: self, decision_type: decision_type, reason: reason)
    transaction do
      update!(status: decision.decision_type) if decision.save
    end
    decision
  end
end
