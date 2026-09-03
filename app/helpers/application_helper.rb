module ApplicationHelper
  STATUS_BADGE = {
    "pending" => "bg-gray-800 text-gray-200",
    "accepted" => "bg-green-950 text-green-300",
    "deferred" => "bg-amber-950 text-amber-300",
    "declined" => "bg-red-950 text-red-300"
  }.freeze

  # Count cards: a crisp border in the status colour, a faint tint over the page
  # background, and text in the same colour as the matching badge.
  STATUS_CARD = {
    "pending" => "border-gray-500 bg-gray-800/20 hover:bg-gray-800/40 text-gray-200",
    "accepted" => "border-green-700 bg-green-950/30 hover:bg-green-950/60 text-green-300",
    "deferred" => "border-amber-700 bg-amber-950/30 hover:bg-amber-950/60 text-amber-300",
    "declined" => "border-red-700 bg-red-950/30 hover:bg-red-950/60 text-red-300"
  }.freeze

  URGENCY_BADGE = {
    "high" => "bg-rose-950 text-rose-300",
    "medium" => "bg-orange-950 text-orange-300",
    "low" => "bg-sky-950 text-sky-300"
  }.freeze

  def status_badge(status, **options)
    badge(status.humanize, STATUS_BADGE.fetch(status), data: { status: status }, **options)
  end

  def status_card_classes(status)
    STATUS_CARD.fetch(status)
  end

  def urgency_badge(urgency, **options)
    badge(urgency.humanize, URGENCY_BADGE.fetch(urgency), data: { urgency: urgency }, **options)
  end

  private
    def badge(text, colours, **options)
      tag.span(text, class: "inline-block rounded-full px-2.5 py-0.5 text-sm font-medium #{colours}", **options)
    end
end
