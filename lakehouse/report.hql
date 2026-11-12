// Read the Delta table `default.events` back and total the placed orders
// per customer.
//
// A table ends, so it is read by `source`, as a `Seq<Event>`, through the
// boundary: its columns are checked against `Event` before any row is
// decoded. A DECIMAL column reads as a Decimal with its digits.

type Event {
    id       : Int
    kind     : String
    customer : String
    amount   : Decimal
    at       : String
}

events : Seq<Event> = source("events")
events
| filter(e => e.kind == "order_placed")
| group(by = e => e.customer)
| map(g => {customer: g.key, orders: g.items | size, total: g.items | map(e => e.amount) | sum})
