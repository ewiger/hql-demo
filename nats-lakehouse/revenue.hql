// Transformation: the silver table read whole, the placed orders totalled
// per customer, and the totals written to the gold Delta table
// `customer_revenue` in one commit that replaces the rows it held.

type Event {
    id       : Int
    kind     : String
    customer : String
    amount   : Decimal
    at       : String
}

type Revenue {
    customer : String
    orders   : Int
    total    : Decimal
}

events : Seq<Event> = source("orders_silver")
events
| filter(e => e.kind == "order_placed")
| group(by = e => e.customer)
| map(g => Revenue(customer = g.key, orders = g.items | size, total = g.items | map(e => e.amount) | sum))
| target("customer_revenue")
