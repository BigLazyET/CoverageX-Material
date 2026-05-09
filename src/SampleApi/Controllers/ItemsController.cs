using Microsoft.AspNetCore.Mvc;
using SampleApi.Models;
using SampleApi.Services;
using SampleLibrary;
using SampleLibrary.Models;

namespace SampleApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ItemsController : ControllerBase
{
    private readonly ItemStore _itemStore;
    private readonly InventoryService _inventoryService;

    public ItemsController(ItemStore itemStore, InventoryService inventoryService)
    {
        _itemStore = itemStore;
        _inventoryService = inventoryService;
    }

    [HttpGet]
    public ActionResult<IEnumerable<Item>> GetAll([FromQuery] string? name, [FromQuery] int? minimumValue)
    {
        IEnumerable<Item> items = _itemStore.GetAll();

        if (!string.IsNullOrWhiteSpace(name))
        {
            items = items.Where(item =>
                !string.IsNullOrWhiteSpace(item.Name) &&
                item.Name.Contains(name, StringComparison.OrdinalIgnoreCase));
        }

        if (minimumValue.HasValue)
        {
            items = items.Where(item => item.Value >= minimumValue.Value);
        }

        return Ok(items.OrderBy(item => item.Id).ToList());
    }

    [HttpGet("{id:int}")]
    public ActionResult<Item> GetById(int id)
    {
        var item = _itemStore.GetById(id);
        return item is null ? NotFound() : Ok(item);
    }

    [HttpPost]
    public ActionResult<Item> Create([FromBody] CreateItemRequest request)
    {
        var validationError = ValidateRequest(request.Name, request.Value);
        if (validationError is not null)
        {
            return validationError;
        }

        var item = _itemStore.Create(request.Name!, request.Value);
        return CreatedAtAction(nameof(GetById), new { id = item.Id }, item);
    }

    [HttpPut("{id:int}")]
    public ActionResult<Item> Update(int id, [FromBody] UpdateItemRequest request)
    {
        var validationError = ValidateRequest(request.Name, request.Value);
        if (validationError is not null)
        {
            return validationError;
        }

        return _itemStore.Update(id, request.Name!, request.Value, out var updatedItem)
            ? Ok(updatedItem)
            : NotFound();
    }

    [HttpDelete("{id:int}")]
    public IActionResult Delete(int id)
    {
        return _itemStore.Delete(id) ? NoContent() : NotFound();
    }

    [HttpGet("stats")]
    public IActionResult GetStats()
    {
        var items = _itemStore.GetAll();
        var totalValue = _inventoryService.GetTotalValue(items);
        var averageValue = items.Count == 0 ? 0 : Math.Round(items.Average(item => item.Value), 2);

        return Ok(new
        {
            count = items.Count,
            totalValue,
            averageValue,
            mostValuableItem = _inventoryService.FindMostValuableItem(items)
        });
    }

    [HttpGet("above-value/{minimumValue:int}")]
    public ActionResult<IEnumerable<Item>> GetItemsAboveValue(int minimumValue)
    {
        return Ok(_inventoryService.GetItemsAboveValue(_itemStore.GetAll(), minimumValue));
    }

    private BadRequestObjectResult? ValidateRequest(string? name, int value)
    {
        if (string.IsNullOrWhiteSpace(name))
        {
            return BadRequest(new { error = "name is required" });
        }

        if (value < 0)
        {
            return BadRequest(new { error = "value must be greater than or equal to zero" });
        }

        return null;
    }
}
