### Title

**AOLite Repository Guide (root)**

---

### Overview

This repository contains the AOLite local AO simulation toolkit. The Lua-facing entry modules live under `lua/aolite` while the **up-stream AO runtime** and its support libraries are vendored as a Git sub-module in `lua/aos`. Example scripts sit in `examples` and Busted tests in `spec`. AGENTS files exist at `lua/aolite/` and `lua/aolite/lib/`, describing those parts in detail. (The upstream project ships its own documentation inside `lua/aos/`.)

### File Summaries

| Path            | Purpose                                                  |
| --------------- | -------------------------------------------------------- |
| `lua/aolite`    | Main entry modules, lightweight scheduler, factories and public API wrappers. |
| `lua/aos`       | Git sub-module: authoritative AO process runtime & shared libraries. |
| `lua/aolite/lib`| Local utility helpers (logging, JSON, serialization).  |
| `examples`      | Standalone scripts demonstrating AOLite usage.          |
| `spec`          | Unit tests using Busted.                                |

### Testing

Run the test suite from the repository root:

```bash
luarocks install busted  # once
make test
```

### Relationships

The high-level modules in `lua/aolite` depend on helpers in `lua/aolite/lib` **and** on the upstream runtime found in `lua/aos/process`. The `aolite.factories.*` adapters create isolated sand-boxed copies of upstream modules (Handlers, AO, Process) for every simulated process. Example scripts and tests simply `require("aolite")` (maps to `lua/aolite/main.lua`).

### Contribution & Style

* Use **2 spaces** for indentation in Lua files and avoid tabs.
* End files with a newline and trim trailing whitespace.
* Reference lines for citations using `F:path#Lstart(-Lend)` where applicable.
* Always run `make test` before committing.
* PR messages should summarize changes and include test results.

This root document provides a quick map of the repository. See nested AGENTS files for deeper technical details and the standard heading layout used across them.
