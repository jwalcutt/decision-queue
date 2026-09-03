class Request < ApplicationRecord
  has_many :decisions, -> { order(:created_at) }, dependent: :destroy

  STATUS_ORDER = %w[pending deferred accepted declined].freeze
  URGENCY_ORDER = %w[high medium low].freeze
  SORTS = {
    "queue" => :queue_order,
    "urgency" => :urgency_order,
    "newest" => :newest_first,
    "oldest" => :oldest_first
  }.freeze

  enum :urgency, { low: "low", medium: "medium", high: "high" }, validate: { allow_nil: true }
  enum :status, { pending: "pending", accepted: "accepted", deferred: "deferred", declined: "declined" },
    default: :pending, validate: true

  validates :title, :problem_statement, :expected_impact, :urgency, presence: true

  # Counts for every status in queue order, zeros included, from one GROUP BY.
  def self.status_counts
    counts = group(:status).count
    STATUS_ORDER.index_with { |status| counts.fetch(status, 0) }
  end

  # Unknown or blank values mean "no filter", so a typo in the URL shows everything.
  scope :with_status, ->(status) { where(status: status) if statuses.key?(status) }
  scope :with_urgency, ->(urgency) { where(urgency: urgency) if urgencies.key?(urgency) }

  # Queue order: still-actionable statuses first, then urgency, then oldest first.
  scope :queue_order, -> {
    in_order_of(:status, STATUS_ORDER, filter: false)
      .in_order_of(:urgency, URGENCY_ORDER, filter: false)
      .order(:created_at, :id)
  }
  scope :urgency_order, -> { in_order_of(:urgency, URGENCY_ORDER, filter: false).order(:created_at, :id) }
  scope :newest_first, -> { order(created_at: :desc, id: :desc) }
  scope :oldest_first, -> { order(:created_at, :id) }

  # Unknown or blank sort means the default queue order, same rule as the filters.
  scope :sorted_by, ->(sort) { public_send(SORTS.fetch(sort, :queue_order)) }

  # Accepted and declined are final in v1; pending and deferred can still be decided.
  def decidable?
    pending? || deferred?
  end

  # Records a decision and moves the request to that state, or does neither.
  # Always returns the decision; an unsaved one carries the validation errors.
  # The row lock means two simultaneous decisions can't both pass the guard.
  def decide(decision_type:, reason:)
    decision = Decision.new(request: self, decision_type: decision_type, reason: reason)
    with_lock do
      update!(status: decision.decision_type) if decision.save
    end
    decision
  end
end
