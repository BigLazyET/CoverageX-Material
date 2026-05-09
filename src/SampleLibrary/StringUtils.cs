namespace SampleLibrary;

public static class StringUtils
{
    public static string Reverse(string s)
    {
        if (s == null) return string.Empty;
        var arr = s.ToCharArray();
        Array.Reverse(arr);
        return new string(arr);
    }

    public static bool IsPalindrome(string s)
    {
        if (s == null) return false;
        var cleaned = new string(s.Where(char.IsLetterOrDigit).Select(char.ToLower).ToArray());
        return cleaned.SequenceEqual(cleaned.Reverse());
    }

    public static string Truncate(string? s, int maxLength)
    {
        if (maxLength < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(maxLength));
        }

        if (string.IsNullOrEmpty(s) || s.Length <= maxLength)
        {
            return s ?? string.Empty;
        }

        if (maxLength <= 3)
        {
            return s[..maxLength];
        }

        return $"{s[..(maxLength - 3)]}...";
    }
}
