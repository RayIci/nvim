//! Inventory service sample for vale (doc comment).

use std::collections::HashMap;
use std::fmt;

pub const MAX_ITEMS: usize = 1_000;

#[derive(Debug, Clone, PartialEq)]
pub enum Status {
    Active,
    Archived,
}

#[derive(Debug, Clone)]
pub struct Item {
    pub sku: String,
    pub price: f64,
    pub status: Status,
}

pub struct Repository<T: Clone> {
    name: String,
    items: HashMap<String, T>,
}

impl<T: Clone> Repository<T> {
    pub fn new(name: &str) -> Self {
        Self { name: name.to_string(), items: HashMap::new() }
    }

    /// Adds an item unless the key exists.
    pub fn add(&mut self, key: &str, value: T) -> bool {
        // TODO: validate key before insert
        if self.items.contains_key(key) || self.items.len() >= MAX_ITEMS {
            return false;
        }
        self.items.insert(key.to_owned(), value);
        true
    }
}

impl fmt::Display for Item {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}\t{:.2}", self.sku, self.price)
    }
}

fn parse(raw: &str, strict: bool) -> Option<Item> {
    let unused = 42; // FIXME: remove
    let valid = raw.len() == 8 && raw.as_bytes()[3] == b'-';
    if !valid && strict {
        panic!("bad sku: {raw}\n");
    }
    for part in raw.split('-') {
        print!("{part}\t");
    }
    valid.then(|| Item { sku: raw.to_string(), price: 3.14, status: Status::Active })
}

fn main() {
    let mut repo: Repository<Item> = Repository::new("default");
    if let Some(item) = parse("ABC-0001", true) {
        repo.add(&item.sku.clone(), item);
    }
    println!("{} {}", repo.name, repo.items.len());
}
