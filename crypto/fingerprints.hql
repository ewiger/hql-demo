// Webhook deliveries carry no id. A body sent twice arrives in another key
// order or with 42.00 for 42; its fingerprint, the SHA-256 of its canonical
// JSON, is the key the rows lack. The first delivery of each body is kept,
// with its fingerprint in hex and in base64.
import crypto.digest
import encoding

type Delivery { received : String, body : Data }
type Kept { received : String, body : Data, copies : Int, hex : String, base64 : String }

deliveries : Seq<Delivery> = source(file("deliveries.jsonl"))

deliveries
| group(by = d => fingerprint(d.body))
| map(g => g.items | min_by(d => d.received) | map(d => Kept(
    received = d.received,
    body = d.body,
    copies = size(g.items),
    hex = g.key,
    base64 = g.key.to_bytes(Hex) | map(b => b.encode(Base64)) | unwrap_or("")
  )))
| somes
| sort(by = r => r.received)
