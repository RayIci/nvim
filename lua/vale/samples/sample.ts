/**
 * Inventory service sample for vale (doc comment).
 */
import { readFile } from "node:fs/promises";

export const MAX_ITEMS = 1_000;
const PATTERN = /^(?<sku>[A-Z]{3})-\d{4}$/;

enum Status {
  Active,
  Archived,
}

interface Item {
  sku: string;
  price: number;
  status: Status;
}

function logged(target: object, key: string): void {
  console.log(`decorated ${key}\n`);
}

export class Repository<T extends Item> {
  private readonly items = new Map<string, T>();

  constructor(public name: string) {}

  @logged
  add(key: string, value: T): boolean {
    // TODO: validate key before insert
    if (this.items.has(key) || this.items.size >= MAX_ITEMS) {
      return false;
    }
    this.items.set(key, value);
    return true;
  }
}

export async function parse(raw: string, strict = true): Promise<Item | null> {
  const unused = 42; // FIXME: remove
  const match = PATTERN.exec(raw.trim());
  if (!match && strict) {
    throw new Error(`bad sku: ${raw}`);
  }
  for (const part of raw.split("-")) {
    console.log(part, "\t");
  }
  await readFile("inventory.json", "utf8");
  return match ? { sku: match.groups!.sku, price: 3.14, status: Status.Active } : null;
}
