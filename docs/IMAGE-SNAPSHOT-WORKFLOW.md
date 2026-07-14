# Image Snapshot Workflow

Last updated: 2026-07-03

Do not commit multi-GB phone images directly into normal git history. It makes
the public repo painful to clone and hard to clean up.

Use local image snapshots for bring-up and rollback:

```text
image-snapshots/<timestamp>-<tag>/
```

Each snapshot contains:

```text
oneplus6t-arch-boot.img
oneplus6t-arch-root.img
manifest.tsv
snapshot-info.tsv
README.md
```

The snapshot script uses reflinks first, then hardlinks. That gives us named
image checkpoints without spending another full 2.5G for each root image on
filesystems that support copy-on-write clones.

Use tags consistently:

```text
known-good-*  booted and validated
bad-*         kept only for debugging, do not flash as rollback
rescue-*      recovery point or rescue boot state
test-*        experimental build, not validated yet
```

For public release, use GitHub releases, release checksums, or Git LFS/annex for
large artifacts. The normal git repo should track scripts, manifests, docs, and
build recipes, not giant binary root images.
