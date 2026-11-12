// Write the raw events to the topic `order_events_raw` as they are, one
// message each, without reading them as any type: a producer upstream
// sends what it sends, and some of these messages are not an `Event`.

source("raw_events") | sink("order_events_raw")
