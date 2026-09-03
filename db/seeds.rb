# Ten sample partner requests so the queue has something to show on first boot.
# Idempotent on title, so `bin/rails db:seed` can run again without duplicating rows.
# Statuses are assigned directly here; matching decision records are seeded
# alongside once the decisions table exists.

requests = [
  {
    title: "Bulk order import for Saltmarsh Provisions",
    problem_statement: "Their buyers re-key weekly orders from a spreadsheet into our portal, one line at a time.",
    expected_impact: "Cuts about six hours of data entry a week and removes the typos that cause short shipments.",
    urgency: "high", status: "pending", created_at: 9.days.ago
  },
  {
    title: "Delivery window alerts for Tidewater Freight",
    problem_statement: "Dispatchers only learn a delivery slipped when the customer calls.",
    expected_impact: "Lets them reroute before a missed window turns into a refund.",
    urgency: "high", status: "pending", created_at: 1.day.ago
  },
  {
    title: "Appointment reminder texts for Brightwater Clinics",
    problem_statement: "Roughly one in eight patients forgets an appointment; staff phone each one by hand the day before.",
    expected_impact: "Fewer empty slots and one less daily chore for the front desk.",
    urgency: "medium", status: "pending", created_at: 6.days.ago
  },
  {
    title: "Author royalty statements for Ferngully Books",
    problem_statement: "Quarterly statements are assembled in a spreadsheet and emailed as PDFs, which takes most of a week.",
    expected_impact: "Statements go out on the first of the month instead of the tenth.",
    urgency: "medium", status: "pending", created_at: 3.days.ago
  },
  {
    title: "Custom report colours for Kestrel Analytics",
    problem_statement: "Their brand palette doesn't match our default chart colours, so exported reports look off-brand.",
    expected_impact: "Nicer looking exports for one partner; no workflow change.",
    urgency: "low", status: "pending", created_at: 12.days.ago
  },
  {
    title: "Member directory search for Lantern Cooperative",
    problem_statement: "Members can only browse the directory alphabetically; finding someone by skill means scrolling.",
    expected_impact: "Useful once the directory passes a few hundred members, which it hasn't yet.",
    urgency: "medium", status: "deferred", created_at: 11.days.ago
  },
  {
    title: "Printable statements for Oakridge Credit Union",
    problem_statement: "A handful of members ask for paper statements and staff format them by hand.",
    expected_impact: "Saves a few minutes per request; volume is low.",
    urgency: "low", status: "deferred", created_at: 8.days.ago
  },
  {
    title: "Two-factor login for Marigold Studio",
    problem_statement: "A shared password leaked and they had to rotate credentials for every staff member.",
    expected_impact: "Closes the gap their insurer flagged and unblocks their renewal.",
    urgency: "high", status: "accepted", created_at: 13.days.ago
  },
  {
    title: "Pallet-level tracking for Pinewood Logistics",
    problem_statement: "Shipments are tracked per truck, so a single misplaced pallet means checking every stop.",
    expected_impact: "Locates a missing pallet in minutes rather than a day of phone calls.",
    urgency: "medium", status: "accepted", created_at: 10.days.ago
  },
  {
    title: "Guest loyalty points for Driftwood Hospitality",
    problem_statement: "They want a points scheme across their three properties.",
    expected_impact: "Unclear; they have no numbers on repeat stays yet.",
    urgency: "low", status: "declined", created_at: 7.days.ago
  }
]

requests.each do |attrs|
  Request.find_or_create_by!(title: attrs[:title]) { |request| request.assign_attributes(attrs) }
end

puts "Seeded #{Request.count} requests"
