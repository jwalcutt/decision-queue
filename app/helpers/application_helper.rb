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

  # Column-header sort toggles cycle none -> ascending -> descending -> none.
  NEXT_SORT_DIRECTION = { nil => "asc", "asc" => "desc", "desc" => nil }.freeze
  SORT_GLYPH = { nil => "\u2195", "asc" => "\u2191", "desc" => "\u2193" }.freeze
  ARIA_SORT = { "asc" => "ascending", "desc" => "descending" }.freeze

  # "asc", "desc", or nil: how the queue is currently sorted on this field.
  def sort_direction(field)
    params[:sort].to_s[/\A#{field}_(asc|desc)\z/, 1]
  end

  # A <th> whose toggle link moves the sort to the next state for this field,
  # keeping the active filters. Deselecting drops the sort back to queue order.
  def sort_header(field, label, **options)
    direction = sort_direction(field)
    next_direction = NEXT_SORT_DIRECTION[direction]
    query = queue_query(sort: next_direction && "#{field}_#{next_direction}")
    description = next_direction ? "Sort by #{label.downcase}, #{next_direction == "asc" ? "ascending" : "descending"}" : "Clear #{label.downcase} sort"
    toggle = link_to(SORT_GLYPH[direction], root_path(**query),
      "aria-label": description, title: description,
      data: { sort: field, direction: direction },
      class: [ "ml-1 px-1 rounded", direction ? "text-blue-400" : "text-gray-500 hover:text-gray-200" ])

    tag.th(**options, "aria-sort": ARIA_SORT[direction], data: { sort: field }) do
      safe_join([ label, toggle ])
    end
  end

  # The queue's current view parameters (filters, sort, rows per page), with
  # blanks dropped. Rows per page is the sanitized value the controller settled
  # on, and the default is left out so plain URLs stay plain. Pass overrides to
  # change or remove keys when building links.
  def queue_query(**overrides)
    per_page = @per_page unless @per_page.nil? || @per_page == RequestsController::PER_PAGE_DEFAULT
    {
      status: params[:status].presence,
      urgency: params[:urgency].presence,
      sort: params[:sort].presence,
      per_page: per_page
    }.merge(overrides).compact
  end

  # Link to a page of the queue, keeping the active filters, sort, and page size.
  # Page 1 carries no page param so the plain queue URL stays canonical.
  def queue_page_path(page)
    root_path(**queue_query(page: (page if page > 1)))
  end

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
