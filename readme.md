# ECHOES Technical Deliverables

This repository converts ECHOES technical deliverables from Microsoft Word (`.docx`) into Markdown for publication with MkDocs or Zensical.

The purpose is to make the deliverable content easier to navigate and to reference at the section level than in the published PDF documents.

> [!IMPORTANT]
> The official ECHOES deliverables are available on the [ECHOES reports page](https://www.echoes-eccch.eu/reports/).

## Contents

- `scripts/` contains the Pandoc conversion scripts and the Lua cleanup filter.
- `deliverables/` contains the converted Markdown files and their extracted media assets, organized by deliverable.

The conversion uses Pandoc to generate GitHub-Flavored Markdown, extract embedded media, and clean Word-specific formatting artifacts.
