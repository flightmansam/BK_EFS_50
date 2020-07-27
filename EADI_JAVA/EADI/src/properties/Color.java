package properties;

public class Color {

    public float r, g, b, a;

    public Color(int red, int grn, int ble, int alf) {
        r = red / 256.0f;
        g = grn / 256.0f;
        b = ble / 256.0f;
        a = alf / 256.0f;
    }

    public Color(int red, int grn, int ble) {
        r = red / 256.0f;
        g = grn / 256.0f;
        b = ble / 256.0f;
        a = 1;
    }

}