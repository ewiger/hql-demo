// Sign the manifest: a detached Ed25519 signature over the manifest file's
// text, in base64, beside the thumbprint of the key that verifies it.
import crypto
import encoding

key = read_private_key(file("keys/rfc8032-test-1.pem"), Pem, Ed25519)

source(file("work/manifest.jsonl"), Text)
| map(text => {
    signature: text.sign(key).encode(Base64),
    key: key.public().thumbprint()
  })
| first
