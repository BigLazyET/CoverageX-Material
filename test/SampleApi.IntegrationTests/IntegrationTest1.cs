using System.Net;
using System.Net.Http.Json;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace SampleApi.IntegrationTests;

public class ApiTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public ApiTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task AddEndpoint_ReturnsSum()
    {
        var client = _factory.CreateClient();
        var resp = await client.GetAsync("/add?a=4&b=5");
        resp.EnsureSuccessStatusCode();
        var value = await resp.Content.ReadFromJsonAsync<int>();
        Assert.Equal(9, value);
    }

    [Fact]
    public async Task Health_ReturnsOk()
    {
        var client = _factory.CreateClient();
        var resp = await client.GetAsync("/health");
        Assert.Equal(HttpStatusCode.OK, resp.StatusCode);
    }
}
