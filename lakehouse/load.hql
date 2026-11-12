// Read the mock events from a JSON file and write them to the Delta table
// `default.events`, in one commit.
//
// The table is created where none exists, a column per field of `Event`:
// `id` BIGINT, `amount` DECIMAL(12,2) as hql.toml says, the rest STRING.
// `mode = "replace"` in hql.toml puts the rows in place of the ones held.

type Event {
    id       : Int
    kind     : String
    customer : String
    amount   : Decimal
    at       : String
}

events : Seq<Event> = source("mock_events")
events | target("events")
