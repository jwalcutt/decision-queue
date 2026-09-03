class Decision < ApplicationRecord
  belongs_to :request

  enum :decision_type, { accepted: "accepted", deferred: "deferred", declined: "declined" },
    validate: { allow_nil: true }

  validates :decision_type, :reason, presence: true
  validate :request_still_decidable, on: :create

  private
    def request_still_decidable
      return if request.nil? || request.decidable?

      errors.add(:base, "This request is already #{request.status}. Accepted and declined decisions are final.")
    end
end
