using SampleLibrary;
using Xunit;

namespace SampleLibrary.UnitTests;

public class IncrementalShippingTests
{
    [Theory]
    [InlineData(0, 5)]
    [InlineData(100, 105)]
    public void Quote_StandardDelivery_AddsFive(int subtotal, int expected)
    {
        Assert.Equal(expected, IncrementalShipping.Quote(subtotal, express: false));
    }
}
