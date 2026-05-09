using System.Net;
using System.Net.Http.Json;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc.Testing;
using SampleLibrary.Models;
using Xunit;

namespace SampleApi.IntegrationTests;

public class ApiItemsTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public ApiItemsTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task Create_Get_Update_Delete_Item()
    {
        var client = _factory.CreateClient();
        var newItem = new Item { Name = "foo", Value = 42 };
        var post = await client.PostAsJsonAsync("/items", newItem);
        post.EnsureSuccessStatusCode();
        var created = await post.Content.ReadFromJsonAsync<Item>();
        Assert.NotNull(created);
        Assert.True(created.Id > 0);

        var get = await client.GetAsync($"/items/{created.Id}");
        get.EnsureSuccessStatusCode();
        var fetched = await get.Content.ReadFromJsonAsync<Item>();
        Assert.Equal("foo", fetched!.Name);

        // update
        created.Name = "bar";
        var put = await client.PutAsJsonAsync($"/items/{created.Id}", created);
        put.EnsureSuccessStatusCode();
        var updated = await put.Content.ReadFromJsonAsync<Item>();
        Assert.Equal("bar", updated!.Name);

        // delete
        var del = await client.DeleteAsync($"/items/{created.Id}");
        Assert.Equal(HttpStatusCode.NoContent, del.StatusCode);

        var getAfter = await client.GetAsync($"/items/{created.Id}");
        Assert.Equal(HttpStatusCode.NotFound, getAfter.StatusCode);
    }

    [Fact]
    public async Task CalcEndpoints_Work()
    {
        var client = _factory.CreateClient();
        var r1 = await client.GetAsync("/calc/mul?a=3&b=4");
        r1.EnsureSuccessStatusCode();
        var v1 = await r1.Content.ReadFromJsonAsync<int>();
        Assert.Equal(12, v1);

        var r2 = await client.GetAsync("/calc/div?a=5&b=2");
        r2.EnsureSuccessStatusCode();
        var v2 = await r2.Content.ReadFromJsonAsync<double>();
        Assert.Equal(2.5, v2);
    }
}
