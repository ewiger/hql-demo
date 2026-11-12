// Read the subject `events.orders` with no configured endpoint: the
// transport is written in the program, by the constructor of the module
// `io.msg.nats_jetstream`, whose parameters are the keys of the
// `nats_jetstream` kind.
//
// Each message is one JSON document, read as `Data`. A constructed
// transport has no schema boundary, so a field is what the message holds:
// `amount` here is the text the boundary of `produce.hql` wrote a Decimal
// as. The address is still named by an environment variable: a constructor
// takes no secret.

import io.msg.nats_jetstream

orders = nats_jetstream("events.orders", stream = "EVENTS", url_env = "NATS_URL", idle_ms = 2000)

tap(orders)
| filter(e => e.kind == "order_placed")
| map(e => {id: e.id, customer: e.customer, amount: e.amount})
