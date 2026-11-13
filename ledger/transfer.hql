// A transfer of 100 from ada to grace, as one transaction (HQL-0051).
//
// The two accounts and the transfers table are participants of one scope
// over one database, so the two updates and the insert hold or fail
// together. The block reads the sender's balance through the scope's own
// connection: `after` sees the update the same attempt made. A balance
// below the amount rolls the attempt back by the program's own rule, and
// the scope's value says so as data, `err(TransactionFailure(…))`. Under
// `Serializable`, a concurrent transfer that conflicts is retried, up to
// three attempts.

type Account { id : Int, owner : String, balance : Decimal }
type Transfer { id : Int, from_id : Int, to_id : Int, amount : Decimal }

accounts = configured("accounts")
transfers = configured("transfers")
ledger = {accounts, transfers}
amount = 100.00

outcome =
    with transaction(attempts = 3, isolation = Serializable) tx on ledger {
        sender = source(accounts) | filter(a => a.id == 1) | one
        tx.rollback("insufficient balance") given sender.balance < amount

        update accounts | filter(a => a.id == 1) | set(a => {balance: a.balance - amount})
        update accounts | filter(a => a.id == 2) | set(a => {balance: a.balance + amount})

        after = source(accounts) | filter(a => a.id == 1) | one
        insert transfers Transfer(id = after.balance | int, from_id = 1, to_id = 2, amount = amount)
    }

match outcome {
    ok(n) => "transferred",
    err(f) => f.kind + ": " + f.reason,
}
