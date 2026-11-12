// Publish each mock event to a subject named for its kind:
// `orders.order_placed`, `orders.payment_failed`, `orders.order_shipped`.
//
// The transport is written in the program by the constructor of the module
// `io.msg.nats`; one `sink` per kind publishes that kind's events. Core
// NATS confirms nothing: a message reaches whoever is subscribed when it
// is published.

import io.msg.nats

type Event {
    id       : Int
    kind     : String
    customer : String
    amount   : Decimal
    at       : String
}

events : Seq<Event> = source("mock_events")

for_kind = (kind: String) => events | filter(e => e.kind == kind)
subject = (kind: String) => nats("orders." + kind, url_env = "NATS_URL")

for_kind("order_placed") | sink(subject("order_placed"))
for_kind("payment_failed") | sink(subject("payment_failed"))
for_kind("order_shipped") | sink(subject("order_shipped"))
