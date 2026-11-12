// Read the subject `events.orders` back from the stream `EVENTS`, one
// message at a time.
//
// A stream is a log that does not end, so it is read by `tap`, as a
// `Stream<Event>`; `source("events")` is a type error. The read ends here
// because the endpoint sets `idle_ms`. Each message decodes as an `Event`,
// so `amount` is a Decimal with the digits it was written with.

type Event {
    id       : Int
    kind     : String
    customer : String
    amount   : Decimal
    at       : String
}

events : Stream<Event> = tap("events")
events
| filter(e => e.kind == "order_placed")
| map(e => {id: e.id, customer: e.customer, amount: e.amount})
