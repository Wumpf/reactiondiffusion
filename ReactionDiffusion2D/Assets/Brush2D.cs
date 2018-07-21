using System.Collections.Concurrent;
using UnityEngine;

[RequireComponent(typeof(LineRenderer))]
public class Brush2D : MonoBehaviour
{
    public struct BrushStroke
    {
        public Vector2 Position;
        public float Radius;
        public float Intensity;
    }
    public ConcurrentQueue<BrushStroke> queuedStrokes = new ConcurrentQueue<BrushStroke>();

    void Start ()
    {
        var circle = GetComponent<LineRenderer>();
        circle.positionCount = 64;
        for (int i = 0; i < circle.positionCount; ++i)
        {
            float f = (float) i / (circle.positionCount - 1) * Mathf.PI * 2.0f;
            circle.SetPosition(i, new Vector3(Mathf.Sin(f), Mathf.Cos(f), 0.0f));
        }

        Cursor.visible = false;
    }

    void Update ()
    {
        transform.position = Camera.main.ScreenToWorldPoint(Input.mousePosition);

        const float minScale = 0.05f;
        const float maxScale = 1.0f;
        const float scaleFactor = 0.05f;

        float scale = Mathf.Clamp(transform.localScale.x * (1.0f + Input.mouseScrollDelta.y * scaleFactor), minScale, maxScale);
        transform.localScale = new Vector3(scale, scale, scale);

        if (Input.GetMouseButton(0) || Input.GetMouseButton(1))
        {
            queuedStrokes.Enqueue(new BrushStroke()
            {
                Position = new Vector2(transform.position.x, transform.position.y),
                Radius = transform.localScale.x,
                Intensity = Input.GetMouseButton(0) ? 10.0f : -10.0f,
            });
        }
    }
}
