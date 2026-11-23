namespace SampleLibrary;

public class Calculator
{
    // Fixture: comment-only change shifts old code without changing its scope.
    public int Add(int a, int b) => a + b;
    public int Sub(int a, int b) => a - b;
    public int Mul(int a, int b) => a * b;
    public double Div(int a, int b)
    {
        if (b == 0) throw new DivideByZeroException("divisor cannot be zero");
        return (double)a / b;
    }
}


public static class IncrementalShipping
{
    public static int Quote(int subtotal, bool express)
    {
        if (express) // fixture: condition
        {
            return subtotal + 20; // fixture: missed
        }

        return subtotal + 5; // fixture: covered
    }

    public static int UnusedDiscount(int subtotal)
    {
        return subtotal - 10; // fixture: unused
    }
}
