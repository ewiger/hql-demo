// Subscribe to every subject under `orders.` and give each placed order's
// id, customer and amount as it arrives.
//
// A core subject keeps nothing, so this program is given only what is
// published while it is subscribed: run.sh starts it before publish.hql.
// It is a `Stream`, and it ends once the subjects have been quiet for
// `idle_ms`.

type Event {
    id       : Int
    kind     : String
    customer : String
    amount   : Decimal
    at       : String
}

events : Stream<Event> = tap("orders")
events
| filter(e => e.kind == "order_placed")
| map(e => {id: e.id, customer: e.customer, amount: e.amount})
