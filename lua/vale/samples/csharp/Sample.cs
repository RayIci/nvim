using System.Text.RegularExpressions;

namespace Vale.Sample;

/// <summary>Inventory service sample for vale (doc comment).</summary>
public enum Status { Active, Archived }

public record Item(string Sku, decimal Price, Status Status = Status.Active);

[Serializable]
public sealed class Repository<T> where T : Item
{
    public const int MaxItems = 1_000;
    private static readonly Regex Pattern = new(@"^(?<sku>[A-Z]{3})-\d{4}$");
    private readonly Dictionary<string, T> _items = new();

    public string Name { get; init; } = "default";

    /// <param name="key">The SKU.</param>
    public bool Add(string key, T value)
    {
        // TODO: validate key before insert
        if (_items.ContainsKey(key) || _items.Count >= MaxItems)
        {
            return false;
        }
        _items[key] = value;
        return true;
    }

    public static Item? Parse(string raw, bool strict = true)
    {
        var unused = 42; // FIXME: remove
        var match = Pattern.Match(raw.Trim());
        if (!match.Success && strict)
        {
            throw new ArgumentException($"bad sku: {raw}\n");
        }
        foreach (var part in raw.Split('-'))
        {
            Console.Write($"{part}\t");
        }
        return match.Success ? new Item(match.Groups["sku"].Value, 3.14m) : null;
    }

    public override string ToString() => $"{this.Name} ({_items.Count}) {true} {null}";
}
