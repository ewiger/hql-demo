// The ledger as the day starts: two accounts, and no transfer yet.
//
// `target` creates each table where none exists, a column per field, and
// replaces its rows. A transfer's `id` counts the transfers made, 1, 2, …,
// so the day's transfers read in the order they were made.

type Account { id : Int, owner : String, balance : Decimal }
type Transfer { id : Int, from_id : Int, to_id : Int, amount : Decimal }

[Account(id = 1, owner = "ada", balance = 250.00),
 Account(id = 2, owner = "grace", balance = 40.00)]
| target("accounts")

[Transfer(id = 0, from_id = 0, to_id = 0, amount = 0.00)]
| target("transfers")

delete configured("transfers")
