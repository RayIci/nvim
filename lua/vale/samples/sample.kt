/**
 * Inventory service sample for vale (doc comment).
 */
package sample

import kotlin.text.Regex

const val MAX_ITEMS: Int = 1_000
private val PATTERN = Regex("""^(?<sku>[A-Z]{3})-\d{4}$""")

enum class Status { ACTIVE, ARCHIVED }

data class Item(val sku: String, val price: Double = 0.0, val status: Status = Status.ACTIVE)

@Suppress("unused")
class Repository<T : Any>(val name: String) {
    private val items = mutableMapOf<String, T>()

    fun add(key: String, value: T): Boolean {
        // TODO: validate key before insert
        if (key in items || items.size >= MAX_ITEMS) {
            return false
        }
        items[key] = value
        return true
    }
}

fun parse(raw: String, strict: Boolean = true): Item? {
    val unused = 42 // FIXME: remove
    val match = PATTERN.find(raw.trim())
    if (match == null && strict) {
        throw IllegalArgumentException("bad sku: $raw\n")
    }
    for (part in raw.split("-")) {
        print("$part\t")
    }
    return match?.let { Item(sku = it.groups["sku"]!!.value, price = 3.14) } ?: null
}
