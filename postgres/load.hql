// Read the mock events from a JSON file and write them to the table
// `events`, in one transaction.
//
// The table is created where none exists, a column per field of `Event`:
// `id` BIGINT, `amount` NUMERIC, the rest TEXT. `mode = "replace"` in
// hql.toml empties the table first and keeps its definition.

type Event {
    id       : Int
    kind     : String
    customer : String
    amount   : Decimal
    at       : String
}

events : Seq<Event> = source("mock_events")
events | target("events")
