# /.github/workflows

CI/CD workflows for SimpleQuestPlates.

## release.yml

Triggered on tag push (`v*`).

Responsibilities:

- Determine release type (`release`, `beta`, `alpha`)
- Extract addon version from `SimpleQuestPlates.toc`
- Feed `docs/CHANGES.md` into release text
- Run our own packager and publishers (`tools/release`) for distribution
- Send Discord notifications on success/failure
