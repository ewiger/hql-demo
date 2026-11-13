// Verify a release folder against the signed manifest: first the signature,
// then each file's digest. A file is unchanged, changed or missing.
import io.env
import io.fs
import crypto
import crypto.digest
import encoding

type Item { path : String, size : Int, sha256 : String }
type Signed { signature : String, key : String }
type Check { path : String, status : String }

root = env.arg("dir") | unwrap_or("release")
public = read_public_key(file("keys/rfc8032-test-1.pub.pem"), Pem, Ed25519)

fn sha256(path: Path) : String =
    source(file(path), Text) | map(t => t.digest(Sha256)) | first | unwrap_or("")

fn status(item: Item, root: String) : String {
    path = Path(root).join(item.path)
    match fs.exists(path) {
        false => "missing",
        true => match sha256(path) == item.sha256 {
            true => "unchanged",
            false => "changed",
        },
    }
}

signed : Seq<Signed> = source(file("work/manifest.sig.json"))
signature = signed | first | map(s => s.signature.to_bytes(Base64) | unwrap_or(Bytes(""))) | unwrap_or(Bytes(""))
valid = source(file("work/manifest.jsonl"), Text) | map(t => t.verify(signature, public)) | first | unwrap_or(false)

manifest : Seq<Item> = source(file("work/manifest.jsonl"))
{
    signature: match valid { true => "valid", false => "invalid" },
    files: manifest | map(i => Check(path = i.path, status = status(i, root)))
}
