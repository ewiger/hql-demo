// A transfer of 100 from ada to grace, as one transaction (HQL-0051).
//
// The two accounts and the transfers table are participants of one scope
// over one database, so the two updates and the insert hold or fail
// together. The block reads through the scope's own connection. A balance
// below the amount rolls the attempt back by the program's own rule, and
// the scope's value says so as data, `err(TransactionFailure(…))`.
//
// Each `update` is bound so that its count is read: an account that does
// not exist changes no row, and the transfer rolls back rather than commit
// half of itself. A transfer's `id` is one more than the transfers made so
// far, counted in the same attempt: under `Serializable` two concurrent
// transfers cannot both count the same number and commit, so the key never
// collides. A concurrent transfer that conflicts is retried, up to three
// attempts.

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

        debited = update accounts | filter(a => a.id == 1) | set(a => {balance: a.balance - amount})
        credited = update accounts | filter(a => a.id == 2) | set(a => {balance: a.balance + amount})
        tx.rollback("no such account") given debited != 1 or credited != 1

        made = source(transfers) | size()
        insert transfers Transfer(id = made + 1, from_id = 1, to_id = 2, amount = amount)
    }

match outcome {
    ok(n) => "transferred",
    err(f) => f.kind + ": " + f.reason,
}
