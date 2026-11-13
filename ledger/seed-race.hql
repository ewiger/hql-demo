// The ledger before a race: ada holds 150, enough for one transfer of 100
// but not two, and no transfer yet. `run.sh` then starts two transfers at
// once; under `Serializable` exactly one may commit.

type Account { id : Int, owner : String, balance : Decimal }
type Transfer { id : Int, from_id : Int, to_id : Int, amount : Decimal }

[Account(id = 1, owner = "ada", balance = 150.00),
 Account(id = 2, owner = "grace", balance = 40.00)]
| target("accounts")

[Transfer(id = 0, from_id = 0, to_id = 0, amount = 0.00)]
| target("transfers")

delete configured("transfers")
