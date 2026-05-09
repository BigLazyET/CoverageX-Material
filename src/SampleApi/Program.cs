using SampleLibrary;
using SampleApi.Services;

var builder = WebApplication.CreateBuilder(args);

builder.WebHost.UseUrls("http://0.0.0.0:20000");

builder.Services.AddSingleton<Calculator>();
builder.Services.AddSingleton<InventoryService>();
builder.Services.AddSingleton<ItemStore>();
builder.Services.AddControllers();

var app = builder.Build();

app.MapControllers();

app.Run();

public partial class Program;
