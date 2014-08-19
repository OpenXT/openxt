function Checked-Copy($src, $dest) {
    copy $src -destination $dest -Force -V
    if (-Not $?) {
        throw "Unable to copy $src to $dest"
    }
}
