class Request < ApplicationRecord
  has_many :decisions, -> { order(:created_at) }, dependent: :destroy

  STATUS_ORDER = %w[pending deferred accepted declined].freeze
  URGENCY_ORDER = %w[high medium low].freeze
  # Sort names are "<field>_<direction>" so the column-header toggles and the
  # sort select speak the same vocabulary. Anything else means queue order.
  # Urgency "ascending" is high first: the header toggle's first click should
  # land on the order people almost always want.
  CONTENT_ATTRIBUTES = %w[title organization problem_statement expected_impact urgency].freeze
  SORTS = {
    "title_asc" => :title_a_to_z,
    "title_desc" => :title_z_to_a,
    "organization_asc" => :organization_a_to_z,
    "organization_desc" => :organization_z_to_a,
    "urgency_asc" => :urgency_high_first,
    "urgency_desc" => :urgency_low_first,
    "status_asc" => :status_pending_first,
    "status_desc" => :status_declined_first,
    "submitted_desc" => :newest_first,
    "submitted_asc" => :oldest_first
  }.freeze

  enum :urgency, { low: "low", medium: "medium", high: "high" }, validate: { allow_nil: true }
  enum :status, { pending: "pending", accepted: "accepted", deferred: "deferred", declined: "declined" },
    default: :pending, validate: true

  validates :title, :organization, :problem_statement, :expected_impact, :urgency, presence: true
  validate :content_frozen_once_decided, on: :update
  before_destroy :only_while_pending

  # Counts for every status in queue order, zeros included, from one GROUP BY.
  def self.status_counts
    counts = group(:status).count
    STATUS_ORDER.index_with { |status| counts.fetch(status, 0) }
  end

  # Unknown or blank values mean "no filter", so a typo in the URL shows everything.
  scope :with_status, ->(status) { where(status: status) if statuses.key?(status) }
  scope :with_urgency, ->(urgency) { where(urgency: urgency) if urgencies.key?(urgency) }
  # Organization is free text, so any non-blank value filters; a name that
  # matches nothing shows the empty state rather than being ignored.
  scope :with_organization, ->(organization) { where(organization: organization) if organization.present? }

  # Queue order: still-actionable statuses first, then urgency, then oldest first.
  scope :queue_order, -> {
    in_order_of(:status, STATUS_ORDER, filter: false)
      .in_order_of(:urgency, URGENCY_ORDER, filter: false)
      .order(:created_at, :id)
  }
  # Alphabetical sorts ignore case so the database collation can't split "acme" from "Acme".
  scope :title_a_to_z, -> { order(arel_table[:title].lower.asc, :created_at, :id) }
  scope :title_z_to_a, -> { order(arel_table[:title].lower.desc, :created_at, :id) }
  scope :organization_a_to_z, -> { order(arel_table[:organization].lower.asc, :created_at, :id) }
  scope :organization_z_to_a, -> { order(arel_table[:organization].lower.desc, :created_at, :id) }
  scope :urgency_high_first, -> { in_order_of(:urgency, URGENCY_ORDER, filter: false).order(:created_at, :id) }
  scope :urgency_low_first, -> { in_order_of(:urgency, URGENCY_ORDER.reverse, filter: false).order(:created_at, :id) }
  scope :status_pending_first, -> { in_order_of(:status, STATUS_ORDER, filter: false).order(:created_at, :id) }
  scope :status_declined_first, -> { in_order_of(:status, STATUS_ORDER.reverse, filter: false).order(:created_at, :id) }
  scope :newest_first, -> { order(created_at: :desc, id: :desc) }
  scope :oldest_first, -> { order(:created_at, :id) }

  # Unknown or blank sort means the default queue order, same rule as the filters.
  scope :sorted_by, ->(sort) { public_send(SORTS.fetch(sort, :queue_order)) }

  # Accepted and declined are final in v1; pending and deferred can still be decided.
  def decidable?
    pending? || deferred?
  end

  # Editing and deleting are allowed only before any decision is recorded.
  def editable?
    pending?
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

  private
    def content_frozen_once_decided
      return if pending? || (changed & CONTENT_ATTRIBUTES).empty?

      errors.add(:base, "This request has been decided and can no longer be edited.")
    end

    def only_while_pending
      return if pending?

      errors.add(:base, "This request has been decided and can no longer be deleted.")
      throw :abort
    end
end
