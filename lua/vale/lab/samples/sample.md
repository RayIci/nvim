# Inventory service

A **sample** document for *vale*, with `inline code` and a [link](https://example.com).

## Setup

1. Install the tools
2. Run the importer

- [x] Parse SKUs
- [ ] Validate prices

> Note: prices are stored as decimals.

```python
def parse(raw: str) -> bool:
    return raw.startswith("ABC")  # fenced code
```

| SKU      | Price |
|----------|-------|
| ABC-0001 | 3.14  |

---
