using SampleLibrary.Models;

namespace SampleLibrary;

public class InventoryService
{
    public int GetTotalValue(IEnumerable<Item>? items)
    {
        if (items is null)
        {
            return 0;
        }

        return items.Sum(item => item.Value);
    }

    public Item? FindMostValuableItem(IEnumerable<Item>? items)
    {
        if (items is null)
        {
            return null;
        }

        Item? bestItem = null;
        foreach (var item in items)
        {
            if (bestItem is null || item.Value > bestItem.Value)
            {
                bestItem = item;
            }
        }

        return bestItem;
    }

    public IReadOnlyList<Item> GetItemsAboveValue(IEnumerable<Item>? items, int minimumValue)
    {
        if (items is null)
        {
            return [];
        }

        return items
            .Where(item => item.Value >= minimumValue)
            .OrderByDescending(item => item.Value)
            .ThenBy(item => item.Id)
            .ToList();
    }
}
