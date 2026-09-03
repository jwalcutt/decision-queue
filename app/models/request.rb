class Request < ApplicationRecord
  STATUS_ORDER = %w[pending deferred accepted declined].freeze
  URGENCY_ORDER = %w[high medium low].freeze

  enum :urgency, { low: "low", medium: "medium", high: "high" }, validate: { allow_nil: true }
  enum :status, { pending: "pending", accepted: "accepted", deferred: "deferred", declined: "declined" },
    default: :pending, validate: true

  validates :title, :problem_statement, :expected_impact, :urgency, presence: true

  # Queue order: still-actionable statuses first, then urgency, then oldest first.
  scope :queue_order, -> {
    in_order_of(:status, STATUS_ORDER, filter: false)
      .in_order_of(:urgency, URGENCY_ORDER, filter: false)
      .order(:created_at)
  }
end
