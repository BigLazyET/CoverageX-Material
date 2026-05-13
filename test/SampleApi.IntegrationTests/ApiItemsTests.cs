using System.Net;
using System.Net.Http.Json;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc.Testing;
using SampleApi.Models;
using SampleLibrary.Models;
using Xunit;

namespace SampleApi.IntegrationTests;

public class ApiItemsTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    private sealed class CalculatorResponse
    {
        public double Result { get; set; }
    }

    public ApiItemsTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task Create_Get_Update_Delete_Item()
    {
        var client = _factory.CreateClient();
        var newItem = new CreateItemRequest { Name = "foo", Value = 42 };
        var post = await client.PostAsJsonAsync("/api/items", newItem);
        post.EnsureSuccessStatusCode();
        var created = await post.Content.ReadFromJsonAsync<Item>();
        Assert.NotNull(created);
        Assert.True(created.Id > 0);

        var get = await client.GetAsync($"/api/items/{created.Id}");
        get.EnsureSuccessStatusCode();
        var fetched = await get.Content.ReadFromJsonAsync<Item>();
        Assert.Equal("foo", fetched!.Name);

        // update
        var updateRequest = new UpdateItemRequest { Name = "bar", Value = created.Value };
        var put = await client.PutAsJsonAsync($"/api/items/{created.Id}", updateRequest);
        put.EnsureSuccessStatusCode();
        var updated = await put.Content.ReadFromJsonAsync<Item>();
        Assert.Equal("bar", updated!.Name);

        // delete
        var del = await client.DeleteAsync($"/api/items/{created.Id}");
        Assert.Equal(HttpStatusCode.NoContent, del.StatusCode);

        var getAfter = await client.GetAsync($"/api/items/{created.Id}");
        Assert.Equal(HttpStatusCode.NotFound, getAfter.StatusCode);
    }

    [Fact]
    public async Task CalcEndpoints_Work()
    {
        var client = _factory.CreateClient();
        var r1 = await client.GetAsync("/api/calculator/multiply?a=3&b=4");
        r1.EnsureSuccessStatusCode();
        var v1 = await r1.Content.ReadFromJsonAsync<CalculatorResponse>();
        Assert.NotNull(v1);
        Assert.Equal(12, v1.Result);

        var r2 = await client.GetAsync("/api/calculator/divide?a=5&b=2");
        r2.EnsureSuccessStatusCode();
        var v2 = await r2.Content.ReadFromJsonAsync<CalculatorResponse>();
        Assert.NotNull(v2);
        Assert.Equal(2.5, v2.Result);
    }
}
