using Microsoft.AspNetCore.Mvc;
using SampleLibrary;

namespace SampleApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CalculatorController : ControllerBase
{
    private readonly Calculator _calculator = new();

    [HttpGet("add")]
    public IActionResult Add([FromQuery] int a, [FromQuery] int b)
    {
        return Ok(new { a, b, operation = "add", result = _calculator.Add(a, b) });
    }

    [HttpGet("subtract")]
    public IActionResult Subtract([FromQuery] int a, [FromQuery] int b)
    {
        return Ok(new { a, b, operation = "subtract", result = _calculator.Sub(a, b) });
    }

    [HttpGet("multiply")]
    public IActionResult Multiply([FromQuery] int a, [FromQuery] int b)
    {
        return Ok(new { a, b, operation = "multiply", result = _calculator.Mul(a, b) });
    }

    [HttpGet("divide")]
    public IActionResult Divide([FromQuery] int a, [FromQuery] int b)
    {
        try
        {
            return Ok(new { a, b, operation = "divide", result = _calculator.Div(a, b) });
        }
        catch (DivideByZeroException)
        {
            return BadRequest(new { error = "divisor cannot be zero" });
        }
    }

    [HttpGet("summary")]
    public IActionResult Summary([FromQuery] int a, [FromQuery] int b)
    {
        object division = b == 0
            ? new { error = "divisor cannot be zero" }
            : new { result = _calculator.Div(a, b) };

        return Ok(new
        {
            a,
            b,
            add = _calculator.Add(a, b),
            subtract = _calculator.Sub(a, b),
            multiply = _calculator.Mul(a, b),
            divide = division
        });
    }
}
