// The Delta table `customer_revenue`: revenue per customer, as revenue.hql
// wrote it.

type Revenue {
    customer : String
    orders   : Int
    total    : Decimal
}

revenue : Seq<Revenue> = source("customer_revenue")
revenue
