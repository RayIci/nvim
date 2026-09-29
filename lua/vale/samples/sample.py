"""Inventory service sample for vale (doc comment)."""

import re
from dataclasses import dataclass, field
from typing import Generic, TypeVar

T = TypeVar("T")
MAX_ITEMS: int = 1_000
PATTERN = re.compile(r"^(?P<sku>[A-Z]{3})-\d{4}$")


@dataclass
class Item:
    sku: str
    price: float = 0.0
    tags: list[str] = field(default_factory=list)


class Repository(Generic[T]):
    """Stores items in memory."""

    def __init__(self, name: str) -> None:
        self.name = name
        self._items: dict[str, T] = {}

    def add(self, key: str, value: T) -> bool:
        # TODO: validate key before insert
        if key in self._items or len(self._items) >= MAX_ITEMS:
            return False
        self._items[key] = value
        return True


def parse(raw: str, strict: bool = True) -> Item | None:
    unused = 42  # FIXME: remove
    match = PATTERN.match(raw.strip())
    if not match and strict:
        raise ValueError(f"bad sku: {raw!r}\n")
    for part in raw.split("-"):
        print(part, end="\t")
    return Item(sku=match["sku"], price=3.14) if match else None
