// The table `order_quarantine` after the quarantine run: each message that
// was not an `Event`, as it arrived, with the rule each one broke. The
// message is the tree the producer sent, so it can be repaired and replayed.

type Rejected {
    id      : Int
    message : Data
    rules   : List<String>
}

rejected : Seq<Rejected> = source("order_quarantine")
rejected
