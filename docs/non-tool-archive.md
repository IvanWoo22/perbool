# Non-tool workflow archive

perbool is limited to reusable bioinformatics command-line tools and shared
libraries. Project- or assay-specific workflows are archived outside the
toolkit branch without code changes before removal.

## RBC workflow

`RBC/` was classified as a project workflow because it embeds a fixed PCR
assay panel, named EGFR/KRAS/TP53 targets, target-specific reference sequences,
and laboratory workflow assumptions. It was not migrated into `Perbool::*` and
none of its files were edited during separation.

The directory and its path-specific Git history were extracted with
`git subtree split` and are stored on the dedicated branch
[`codex/archive-rbc-workflow`](https://github.com/IvanWoo22/perbool/tree/codex/archive-rbc-workflow).

Archive identity:

- Archive commit: `20d858772457c2b59c84c31861b39abfe1ad99d0`
- Original `RBC/` tree: `d7f0fd99f792f373e031ce9f1c7e8a251c0134b7`
- Archive branch root tree: `d7f0fd99f792f373e031ce9f1c7e8a251c0134b7`
- Archived files: `RBC.pl`, `RBC_bowtie2.pl`, `RBC_merged.pl`, and `README.md`

The identical tree hashes prove that archival changed neither file content nor
file modes. Further RBC work belongs outside perbool and must not be merged
back into the toolkit command registry.
