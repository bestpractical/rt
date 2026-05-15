# Third-Party Metadata Schema

Each subdirectory of `devel/third-party/` contains a vendored third-party
library together with a `metadata.yml` describing it. This file documents
the schema of those metadata files.

`metadata.yml` is the single source of truth for what we ship and from
where. The aggregate `devel/third-party/README` is generated from the
per-library metadata. Narrative upgrade/build instructions for each
library live in a per-library `README` (or other file named by
`upgrade-instructions:`).

## File layout

Each library lives in its own directory containing at minimum:

- `metadata.yml` — this schema.
- `LICENSE` (or `LICENSE.md`, `COPYING.GPL`, etc.) — upstream license text.
- `README` — narrative upgrade/build instructions (when one exists).
- Library source files, patches, and anything else upstream ships that
  we keep around.

Directories drop the version suffix where practical (`bootstrap/`,
`tom-select/`). A handful retain the major version in the name
(`chart-js-4/`, `ckeditor5/`, `dropzone-7/`) — kept when the upstream
package is commonly referred to that way.

## Fields

Every `metadata.yml` opens with the same boilerplate header comment and
uses the same field ordering as below. Use `~` (YAML null) for fields
that don't apply or whose value is unknown.

### `name` *(string)*

Canonical library name as the world refers to it. Matches upstream's
package name where one exists.

### `version` *(quoted string)*

The version we actually ship, always quoted. YAML would parse `5.10` as
the float `5.1`. Use the upstream release tag even if a source-file
banner disagrees; note any discrepancy in `notes:`.

### `upstream.homepage` *(URL)*

Project home page. Often a docs site distinct from the source repo.

### `upstream.repository` *(URL)*

Source repository (typically GitHub).

### `license.spdx` *(SPDX identifier)*

A valid SPDX expression: `MIT`, `Apache-2.0`, `GPL-2.0-or-later`,
`BSD-3-Clause`, `0BSD`. For dual-licensed code where we choose one side,
set the side we use.

### `license.file` *(path or `~`)*

Relative path inside this directory to the operative license text. For
dual-licensed code this points at the file we actually rely on (e.g.
`COPYING.GPL` for CKEditor 5, where `LICENSE.md` is the upstream-shipped
summary). Use `~` only when no license file is present in-tree, and
follow up to add one.

### `purl` *(Package URL or `~`)*

[Package URL](https://github.com/package-url/purl-spec) used to correlate
this vendored copy with upstream advisory databases. Prefer the form
that resolves against the artifact we actually ship:

- npm release: `pkg:npm/<name>@<version>` (or `pkg:npm/@scope/name@version`
  for scoped packages).
- GitHub tag that was never published to npm: `pkg:github/<owner>/<repo>@<version>`.
- Neither resolves cleanly (e.g. a fork whose npm name would match the
  *wrong* upstream package): `~`, with the reason in `notes:`.

### `cpe` *(CPE 2.3 identifier or `~`)*

NVD CPE when one exists upstream. Usually `~`. Some scanners match
NVD-tracked vulnerabilities by CPE rather than purl.

### `description` *(string)*

One-line human-readable description. Goes into the generated top-level
README.

### `shipped` *(boolean)*

`true` if the library is included in RT's distribution and runs on
end-user installs. `false` for dev-only tooling.

### `security-critical` *(boolean)*

`true` if the library *parses or interprets untrusted input, or executes
or evaluates untrusted strings*. This drives CVE-triage priority: a
vulnerability in a `true` library is a drop-everything event; in a
`false` library it batches into the next release.

The criterion is narrower than "could a bug here affect users." Almost
any shipped library could in principle have a bug that affects users;
this flag is specifically about whether an untrusted-input path runs
through the library itself.

- `true` examples: `ckeditor5` (parses HTML), `htmx` (interprets
  attributes that may carry user values), `jquery` (selector parsing),
  `tom-select` (autocomplete on typed input), `dropzone` (handles user
  files), `tempus-dominus` (date string parsing).
- `false` examples: `popper` (geometric math; no user input),
  `chart.js` (renders app-supplied data), `d3` (presentational),
  `mousetrap` (keyboard binding).

### `upgrade-instructions` *(path or `~`)*

Path (relative to this directory) of the human-readable file describing
how to update this library. Conventionally `README`. `~` if no such
file exists yet — flag for follow-up.

### `artifacts` *(list, may be empty)*

Source-to-destination file mappings produced by a re-build:

```yaml
artifacts:
  - from: <path relative to upstream's build output>
    to:   <path relative to RT source root>
```

Documents where artifacts land in the RT tree. Currently informational;
future tooling may use them to verify that what is in `share/static/`
matches what `metadata.yml` claims. Use `[]` when no build/copy
procedure has been documented yet.

### `patches` *(list, may be empty)*

Local modifications carried on top of upstream:

```yaml
patches:
  - file: <patch filename in this directory>
    reason: <short rationale>
```

Keep `reason:` short. If the rationale is long, summarize and point at
the per-library `README` for full context.

### `notes` *(string or `~`)*

Free-form. Dual-license caveats, version-banner oddities, fork lineage,
intentional version pinning, anything else that doesn't fit elsewhere.

## Common patterns

**Single-file libraries.** Some libraries ship as a single JS file
(`jquery/jquery-3.6.0.js`, `mousetrap/mousetrap-1.5.3.js`). The
`metadata.yml` lives in the same directory. `artifacts:` lists the file
itself; `upgrade-instructions:` may be `~` if the upgrade is just
"drop in the new file."

**Forks of inactive upstreams.** When we ship a maintained fork of an
inactive original (`dropzone`, `chartjs-plugin-colorschemes`), point
`upstream.repository` at the fork. Record the lineage in `notes:`.

**Dual-licensed code.** When upstream offers a choice of licenses and
we pick one, set `license.spdx` to our choice and `license.file` to the
operative license text. Retain any upstream summary file (e.g.
`LICENSE.md`) for downstream visibility into the dual-license
arrangement; mention it in `notes:`. See `ckeditor5/` for a worked
example.

**Libraries with no in-tree assets.** When the bundled assets are
distributed elsewhere in the RT tree (`bootstrap-icons` SVGs land
directly under `share/static/images/`, driven by the `%SVG` config
variable), the directory still holds `metadata.yml` plus license info.
`artifacts:` may be `[]`; a stub `README` should explain where the
content actually lives.

