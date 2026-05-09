using System;
using SampleLibrary;
using SampleLibrary.Models;
using Xunit;

namespace SampleLibrary.UnitTests;

public class CalculatorTests
{
    [Fact]
    public void Add_ReturnsSum()
    {
        var c = new Calculator();
        Assert.Equal(3, c.Add(1, 2));
    }

    // [Fact]
    // public void Sub_ReturnsDifference()
    // {
    //     var c = new Calculator();
    //     Assert.Equal(1, c.Sub(3, 2));
    // }

    [Fact]
    public void Mul_ReturnsProduct()
    {
        var c = new Calculator();
        Assert.Equal(6, c.Mul(2, 3));
    }

    [Fact]
    public void Div_ReturnsQuotient()
    {
        var c = new Calculator();
        Assert.Equal(2.5, c.Div(5, 2));
    }

    [Fact]
    public void Div_ByZero_Throws()
    {
        var c = new Calculator();
        Assert.Throws<DivideByZeroException>(() => c.Div(1, 0));
    }
}

public class StringUtilsTests
{
    [Fact]
    public void Reverse_Works()
    {
        Assert.Equal("cba", StringUtils.Reverse("abc"));
    }

    [Fact]
    public void Reverse_Null_ReturnsEmptyString()
    {
        Assert.Equal(string.Empty, StringUtils.Reverse(null!));
    }

    [Theory]
    [InlineData("A man a plan a canal Panama")]
    [InlineData("racecar")]
    public void IsPalindrome_Works(string s)
    {
        Assert.True(StringUtils.IsPalindrome(s));
    }

    [Fact]
    public void IsPalindrome_Null_ReturnsFalse()
    {
        Assert.False(StringUtils.IsPalindrome(null!));
    }

    [Fact]
    public void Truncate_AddsEllipsis_WhenTextIsTooLong()
    {
        Assert.Equal("Hello...", StringUtils.Truncate("Hello world", 8));
    }

    [Fact]
    public void Truncate_ReturnsOriginal_WhenTextFits()
    {
        Assert.Equal("Hello", StringUtils.Truncate("Hello", 10));
    }

    // [Fact]
    // public void Truncate_WithVerySmallMaxLength_DoesNotAddEllipsis()
    // {
    //     Assert.Equal("He", StringUtils.Truncate("Hello", 2));
    // }

    [Fact]
    public void Truncate_WithNegativeMaxLength_Throws()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => StringUtils.Truncate("Hello", -1));
    }
}

public class InventoryServiceTests
{
    [Fact]
    public void GetTotalValue_ReturnsSumOfValues()
    {
        var service = new InventoryService();
        var items = new[]
        {
            new Item { Id = 1, Name = "Keyboard", Value = 80 },
            new Item { Id = 2, Name = "Mouse", Value = 20 },
            new Item { Id = 3, Name = "Monitor", Value = 200 }
        };

        Assert.Equal(300, service.GetTotalValue(items));
    }

    // [Fact]
    // public void GetTotalValue_WithNullItems_ReturnsZero()
    // {
    //     var service = new InventoryService();

    //     Assert.Equal(0, service.GetTotalValue(null));
    // }

    [Fact]
    public void FindMostValuableItem_ReturnsItemWithLargestValue()
    {
        var service = new InventoryService();
        var items = new[]
        {
            new Item { Id = 1, Name = "Keyboard", Value = 80 },
            new Item { Id = 2, Name = "Mouse", Value = 20 },
            new Item { Id = 3, Name = "Monitor", Value = 200 }
        };

        var result = service.FindMostValuableItem(items);

        Assert.NotNull(result);
        Assert.Equal(3, result.Id);
        Assert.Equal("Monitor", result.Name);
    }

    [Fact]
    public void FindMostValuableItem_WithEmptyCollection_ReturnsNull()
    {
        var service = new InventoryService();

        Assert.Null(service.FindMostValuableItem(Array.Empty<Item>()));
    }

    [Fact]
    public void GetItemsAboveValue_FiltersAndSortsItems()
    {
        var service = new InventoryService();
        var items = new[]
        {
            new Item { Id = 3, Name = "Keyboard", Value = 80 },
            new Item { Id = 1, Name = "Mouse", Value = 80 },
            new Item { Id = 2, Name = "Cable", Value = 10 },
            new Item { Id = 4, Name = "Monitor", Value = 200 }
        };

        var result = service.GetItemsAboveValue(items, 50);

        Assert.Collection(
            result,
            item => Assert.Equal(4, item.Id),
            item => Assert.Equal(1, item.Id),
            item => Assert.Equal(3, item.Id));
    }

    [Fact]
    public void GetItemsAboveValue_WithNullItems_ReturnsEmptyList()
    {
        var service = new InventoryService();

        Assert.Empty(service.GetItemsAboveValue(null, 50));
    }
}
