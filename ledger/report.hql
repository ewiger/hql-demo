// The ledger after the day: each account's balance, and the transfers in
// the order they were made.

type Account { id : Int, owner : String, balance : Decimal }
type Transfer { id : Int, from_id : Int, to_id : Int, amount : Decimal }

accounts : Seq<Account> = source("accounts")
transfers : Seq<Transfer> = source("transfers")

{
    balances: accounts | map(a => {owner: a.owner, balance: a.balance}) | List,
    transfers: transfers | map(t => {from_id: t.from_id, to_id: t.to_id, amount: t.amount}) | List,
}
