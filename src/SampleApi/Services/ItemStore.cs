using System.Collections.Concurrent;
using SampleLibrary.Models;

namespace SampleApi.Services;

public class ItemStore
{
    private readonly ConcurrentDictionary<int, Item> _items = new();
    private int _idCounter;

    public ItemStore()
    {
        Create("Keyboard", 120);
        Create("Mouse", 60);
        Create("Monitor", 899);
    }

    public IReadOnlyCollection<Item> GetAll()
    {
        return _items.Values
            .OrderBy(item => item.Id)
            .ToList();
    }

    public Item? GetById(int id)
    {
        return _items.TryGetValue(id, out var item) ? item : null;
    }

    public Item Create(string name, int value)
    {
        var id = Interlocked.Increment(ref _idCounter);
        var item = new Item
        {
            Id = id,
            Name = name,
            Value = value
        };

        _items[id] = item;
        return item;
    }

    public bool Update(int id, string name, int value, out Item? updatedItem)
    {
        updatedItem = null;

        if (!_items.ContainsKey(id))
        {
            return false;
        }

        updatedItem = new Item
        {
            Id = id,
            Name = name,
            Value = value
        };

        _items[id] = updatedItem;
        return true;
    }

    public bool Delete(int id)
    {
        return _items.TryRemove(id, out _);
    }
}
