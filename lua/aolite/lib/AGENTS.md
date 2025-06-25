### Title

**AOLite Lib: Core Utility Modules (`lua/aolite/lib`)**

---

### Overview

Foundational helper layer for AOLite agents:

* `json` — standalone JSON encode/decode.
* `log` — formatted printing, big-int aware and human-readable (`hr`).
* `serialize` — table→table serializer with big-int support & cycle detection.
* `bint` — 256-bit fixed-width arbitrary-precision integers **provided by the upstream sub-module** (`lua/aos/process/bint.lua`) and exposed locally via `require(".bint")(256)`.

All other runtime packages (e.g. `ao`, `process`) lean on this folder for math, encoding, logging, pattern matching and pure-Lua functional glue.

Refer to the root `AGENTS.md` for repository layout and contribution guidelines. The main runtime using these helpers lives upstream in `lua/aos/process/` (see that sub-module's own documentation).

---

### Key Data Structures & Fields

| Module          | Structure / Constant                                                   | Details                                                                                                                                       |
| --------------- | ---------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| **`json`**      | `escape_char_map`, `char_func_map`                                     | Lookup tables used during encode/decode.                                                                                                      |
| **`log`**       | `Colors` (inherited), functions: `debug/warn/info`                     | `createPrintFunction(level)` returns gated printer based on `_G.PrintVerb`.                                                                   |
| **`serialize`** | `serializeKey`, `serializeValue`, `reconstructKey`, `reconstructValue` | Convert any Lua object + `bint`s to plain-table form and back. Preserves numbers/strings/bools; special markers for `bint` and circular refs. |
| **`bint`** (upstream)     | `bint` metatable (one per *bit-size*)                                  | Array of `BINT_SIZE` words; metamethods implement all Lua numeric & bitwise operators.                                                        |

---

### Key Functions

| Function                                                                         | Module        | Brief Usage                                                                                                          |
| -------------------------------------------------------------------------------- | ------------- | -------------------------------------------------------------------------------------------------------------------- |
| `newmodule(bits, wordbits?)`                                                     | **bint**      | `require("...bint")(256)` → returns a *bit-size-specific* class. Memoized.                                           |
| `bint.zero / one / mininteger / maxinteger, ipow`                                | **bint** (upstream) | Core numeric helpers exposed by upstream library.                                                                     |
| `bint.fromuinteger / frominteger / frombase / fromstring / new / tobint / parse` | **bint**      | Construction helpers for every common source type.                                                                   |
| Arithmetic metamethods (`__add`, `__mul`, `__idiv`, …)                           | **bint**      | Operate on integer arrays; silently falls back to Lua numbers if either operand isn't a `bint`.                      |
| `bint.udivmod / idivmod / tdivmod`                                               | **bint**      | Unsigned, floor, or truncating division + remainder in one pass.                                                     |
| `bint.ipow / upowmod`                                                            | **bint**      | Integer exponentiation (with/without modulus).                                                                       |
| `json.encode / json.decode`                                                      | **json**      | Stand-alone, no external deps; throws on invalid types, circular refs, NaN±Inf.                                      |
| `log.hr(number, denom, decimals?)`                                               | **log**       | Convert `bint` fixed-point → human string, optional rounding.                                                        |
| `log.debug / warn / info`                                                        | **log**       | Runtime-controlled verbosity; renders nested tables and `bint`s.                                                     |
| `serialize.serialize(obj)`                                                       | **serialize** | Converts arbitrary Lua graph to serializable table (string/number/bool/nil) keeping `bint` as `{__bint=...}` tokens. |
| `serialize.reconstruct(obj)`                                                     | **serialize** | Rebuilds original structure, reinstantiating `bint`s and complex keys.                                               |

---

### Relationships

* `log` and `serialize` both `require(".bint")(256)` (aliased to the upstream implementation) to remain size-agnostic (256-bit default).
* `serialize` & `log` call `bint.isbint` to treat big-ints specially.
* `json` is dependency-free; used by `ao.send`, logging, mock network, etc.

---

### Usage Flow (Typical)

1. **Instantiate big-ints**

   ```lua
   local bint = require(".bint")(256)   -- maps to upstream aos.process.bint
   local x = bint("12345678901234567890")
   ```
2. **Human-render** with `log.hr`

   ```lua
   local log = require("aolite.lib.log")
   print(log.hr(x, 8, 4))  -- fixed-point pretty print
   ```
3. **Serialize state** for IPC/storage

   ```lua
   local ser = require("aolite.lib.serialize")
   local blob = ser.serialize({ balance = x })
   -- later
   local restored = ser.reconstruct(blob)
   ```
4. *(Step removed – `utils.lua` has migrated upstream and is loaded transparently through the compatibility layer when required by runtime components.)*

---

### File Summaries

| File            | Purpose                                                                                                                                     | Highlighted APIs                                                        |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| `json.lua`      | Lightweight JSON encoder/decoder (no C libs). Strict: errors on NaN/Inf, sparse arrays, circular refs.                                      | `json.encode`, `json.decode`.                                           |
| `log.lua`       | Verbosity-aware printing, `bint`-aware decimal formatter (`hr`), recursive table pretty-printer.                                            | `hr`, `debug`, `warn`, `info`.                                          |
| `serialize.lua` | Lossless serializer/reconstructor supporting unusual keys and `bint`s; prevents infinite recursion.                                         | `serialize`, `reconstruct`.                                             |
| `bint.lua` *(upstream)* | Authoritative big-int implementation vendored in `lua/aos/process/bint.lua` and accessed via `require(".bint")`. | `newmodule`, arithmetic, comparison, `ipow`, `udivmod`.                 |

---

With these modules documented, an LLM can fully emulate math, encoding, logging, serialization and functional helpers that the larger AOLite agent runtime expects.

### Testing

Run the repository test suite:

```bash
make test
```
