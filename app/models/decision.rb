class Decision < ApplicationRecord
  belongs_to :request

  enum :decision_type, { accepted: "accepted", deferred: "deferred", declined: "declined" },
    validate: { allow_nil: true }

  validates :decision_type, :reason, presence: true
end
