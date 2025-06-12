### Title

**AOLite Repository Guide (root)**

---

### Overview

This repository contains the AOLite local AO simulation toolkit. The Lua modules live under `lua/aolite`, example scripts under `examples`, and Busted tests under `spec`. AGENTS files exist at `lua/aolite/`, `lua/aolite/lib/`, and `lua/aolite/ao/` describing those parts in detail.

### File Summaries

| Path            | Purpose                                                  |
| --------------- | -------------------------------------------------------- |
| `lua/aolite`    | Main entry modules, scheduler and API wrappers.         |
| `lua/aolite/lib`| Utility libraries used everywhere.                      |
| `lua/aolite/ao` | Embedded AO runtime executed inside each process.       |
| `examples`      | Standalone scripts demonstrating AOLite usage.          |
| `spec`          | Unit tests using Busted.                                |

### Testing

Run the test suite from the repository root:

```bash
luarocks install busted  # once
make test
```

### Relationships

The high level modules in `lua/aolite` depend on helpers in `lua/aolite/lib` and on the runtime in `lua/aolite/ao`. Example scripts and tests import the top level module defined in `lua/aolite/main.lua`.

### Contribution & Style

* Use **2 spaces** for indentation in Lua files and avoid tabs.
* End files with a newline and trim trailing whitespace.
* Reference lines for citations using `F:path#Lstart(-Lend)` where applicable.
* Always run `make test` before committing.
* PR messages should summarize changes and include test results.

This root document provides a quick map of the repository. See nested AGENTS files for deeper technical details and the standard heading layout used across them.
