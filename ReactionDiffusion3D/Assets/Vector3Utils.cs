using UnityEngine;

static class Vector3Utils
{
    public static Vector3 From(float f)
    {
        return new Vector3(f, f, f);
    }

    public static Vector3 From(Vector2 v, float z = 0.0f)
    {
        return new Vector3(v.x, v.y, z);
    }
}
