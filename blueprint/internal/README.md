# Internal working materials

These are dated working documents from March 2026 (audits, designs, notes) that sit behind the reference design in the parent directory. They are kept as provenance: they show how the design was criticised and what was proposed next, not what is current.

- [`audits/2026-03-07-blueprint-audit.md`](audits/2026-03-07-blueprint-audit.md): a self-audit of the design. It carries an errata block at the top, because later review showed several findings to be wrong (`ccusage` and `canUseTool` do exist) and none of its fixes were applied.
- [`designs/2026-03-07-proposed-improvements.md`](designs/2026-03-07-proposed-improvements.md): a critique of the design and proposed changes (workflow profiles, fewer agents, schema validation, pre-flight checks). Success-rate figures in it are targets, not results. It is the most useful document here for seeing how the design was meant to change.
- [`designs/2026-03-08-internal-folder-structure.md`](designs/2026-03-08-internal-folder-structure.md): a folder convention for these materials.

The empty subfolders (`decisions`, `notes`, `plans`, `research`, `reviews`) are placeholders from that convention and hold no content.

The reference design itself is in [`../README.md`](../README.md). The system as built is described in [the implementation architecture](../../docs/architecture.md).
