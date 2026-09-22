# ECHOES Technical Deliverables

This repository converts ECHOES technical deliverables from Microsoft Word (`.docx`) into Markdown for publication with MkDocs or Zensical.

The purpose is to make the deliverable content easier to navigate and to reference at the section level than in the published PDF documents.

> [!IMPORTANT]
> The official ECHOES deliverables are available on the [ECHOES reports page](https://www.echoes-eccch.eu/reports/).

## Contents

- `scripts/` contains the Pandoc conversion scripts and the Lua cleanup filter.
- `deliverables/` contains the converted Markdown files and their extracted media assets, organized by deliverable.

The conversion uses Pandoc to generate GitHub-Flavored Markdown, extract embedded media, and clean Word-specific formatting artifacts.

## Convert all deliverables

Install [Pandoc](https://pandoc.org/) and make sure `pandoc.exe` is available on your `PATH`. Place exactly one `.docx` file in each `deliverables/D*/` folder, then run the following command from the repository root:

```bat
scripts\convert-all-D-folders.bat
```

The script converts each source file to `output.md` in the same deliverable folder and extracts embedded files to its `media/` directory. Folders with no source file or more than one `.docx` file are skipped.
