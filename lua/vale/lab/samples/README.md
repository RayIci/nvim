# vale lab samples

Every code sample covers the same **token checklist** (where the language has
the construct), so a colour is always judged across languages, not just one.

| # | Token | Role in `semantics.lua` |
|---|-------|-------------------------|
| 1 | keyword (declaration/storage) | `keyword` |
| 2 | control-flow keyword | `keyword_control` |
| 3 | function definition | `func` |
| 4 | function call | `func` |
| 5 | method | `func` |
| 6 | parameter | `parameter` |
| 7 | type / class | `type` |
| 8 | builtin type | `type_builtin` |
| 9 | property / field | `property` |
| 10 | constant / enum member | `constant` |
| 11 | number | `number` |
| 12 | boolean / null | `boolean` |
| 13 | string | `string` |
| 14 | escape sequence | `escape` |
| 15 | regex | `regex` |
| 16 | comment | `comment` |
| 17 | doc comment | `comment` |
| 18 | TODO / FIXME marker | diagnostics colours |
| 19 | decorator / attribute / annotation | `decorator` |
| 20 | operator | `operator` |
| 21 | punctuation | `punctuation` |
| 22 | namespace / import | `namespace` |
| 23 | generic type parameter | `type` |
| 24 | `this` / `self` | `builtin` |
| 25 | a deliberate warning (unused variable) | `warn` / `unnecessary` |

C#, Java and Rust live in minimal projects (`csharp/`, `java/`, `rust/`) so
roslyn, jdtls and rust-analyzer attach and LSP semantic tokens show up.
