// Ingestion: publish the raw events to the subject `orders.raw` as they
// are, one message each, without reading them as any type. A producer
// upstream sends what it sends, and some of these messages are not an
// `Event`.

source("raw_events") | sink("orders_raw")
