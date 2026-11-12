// Read the subject through the durable consumer `billing`, and give the id
// of each event.
//
// The consumer is the server's record of how far this reader has come. The
// first run reads every event; a run after it reads only what was
// published since, which here is nothing. A message is acknowledged once
// the program asks for the one after it, so a run that fails is given its
// last message again.

type Event {
    id       : Int
    kind     : String
    customer : String
    amount   : Decimal
    at       : String
}

events : Stream<Event> = tap("billing")
events | map(e => e.id)
