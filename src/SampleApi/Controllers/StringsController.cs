using Microsoft.AspNetCore.Mvc;
using SampleLibrary;

namespace SampleApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class StringsController : ControllerBase
{
    [HttpGet("reverse")]
    public IActionResult Reverse([FromQuery] string? input)
    {
        return Ok(new
        {
            input,
            result = StringUtils.Reverse(input ?? string.Empty)
        });
    }

    [HttpGet("palindrome")]
    public IActionResult Palindrome([FromQuery] string? input)
    {
        return Ok(new
        {
            input,
            isPalindrome = StringUtils.IsPalindrome(input ?? string.Empty)
        });
    }

    [HttpGet("truncate")]
    public IActionResult Truncate([FromQuery] string? input, [FromQuery] int maxLength = 10)
    {
        try
        {
            return Ok(new
            {
                input,
                maxLength,
                result = StringUtils.Truncate(input, maxLength)
            });
        }
        catch (ArgumentOutOfRangeException)
        {
            return BadRequest(new { error = "maxLength must be greater than or equal to zero" });
        }
    }

    [HttpGet("analyze")]
    public IActionResult Analyze([FromQuery] string? input)
    {
        var value = input ?? string.Empty;

        return Ok(new
        {
            input = value,
            length = value.Length,
            reversed = StringUtils.Reverse(value),
            isPalindrome = StringUtils.IsPalindrome(value),
            preview = StringUtils.Truncate(value, 12)
        });
    }
}
