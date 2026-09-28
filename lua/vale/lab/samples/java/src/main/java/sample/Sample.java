package sample;

import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.regex.Pattern;

/**
 * Inventory service sample for vale (doc comment).
 */
public final class Sample<T extends Sample.Item> {
    public static final int MAX_ITEMS = 1_000;
    private static final Pattern PATTERN = Pattern.compile("^(?<sku>[A-Z]{3})-\\d{4}$");

    public enum Status { ACTIVE, ARCHIVED }

    public record Item(String sku, double price, Status status) {}

    private final Map<String, T> items = new HashMap<>();
    private final String name;

    public Sample(String name) {
        this.name = name;
    }

    /** @param key the SKU */
    public boolean add(String key, T value) {
        // TODO: validate key before insert
        if (items.containsKey(key) || items.size() >= MAX_ITEMS) {
            return false;
        }
        items.put(key, value);
        return true;
    }

    @SuppressWarnings("unused")
    public static Optional<Item> parse(String raw, boolean strict) {
        int unused = 42; // FIXME: remove
        var match = PATTERN.matcher(raw.trim());
        if (!match.matches() && strict) {
            throw new IllegalArgumentException("bad sku: " + raw + "\n");
        }
        for (String part : raw.split("-")) {
            System.out.print(part + "\t");
        }
        return match.matches() ? Optional.of(new Item(match.group("sku"), 3.14, Status.ACTIVE)) : Optional.empty();
    }

    @Override
    public String toString() {
        return this.name + " " + true + " " + null;
    }
}
