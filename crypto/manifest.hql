// The manifest of a release folder: each file's path within the folder,
// its size and its SHA-256, one JSON document per file.
import io.env
import io.fs
import crypto.digest

type Item { path : String, size : Int, sha256 : String }

root = env.arg("dir") | unwrap_or("release")

fs.folder(root).walk()
| filter(e => e.kind == "file")
| map(e => Item(
    path = e.path.text[size(root) + 1:],
    size = e.size | unwrap_or(0),
    sha256 = source(file(e.path), Text) | map(t => t.digest(Sha256)) | first | unwrap_or("")))
