class Request < ApplicationRecord
  enum :urgency, { low: "low", medium: "medium", high: "high" }, validate: { allow_nil: true }
  enum :status, { pending: "pending", accepted: "accepted", deferred: "deferred", declined: "declined" },
    default: :pending, validate: true

  validates :title, :problem_statement, :expected_impact, :urgency, presence: true
end
