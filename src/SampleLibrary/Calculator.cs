namespace SampleLibrary;

public class Calculator
{
    public int Add(int a, int b) => a + b;
    public int Sub(int a, int b) => a - b;
    public int Mul(int a, int b) => a * b;
    public int Square(int value) => value * value;
    public int Cube(int value) => value * value * value;
    public double Div(int a, int b)
    {
        if (b == 0) throw new DivideByZeroException("divisor cannot be zero");
        return (double)a / b;
    }

    public double Sin(double angleRadians) => Math.Sin(angleRadians);
    public double Cos(double angleRadians) => Math.Cos(angleRadians);
    public double Tan(double angleRadians) => Math.Tan(angleRadians);
}
