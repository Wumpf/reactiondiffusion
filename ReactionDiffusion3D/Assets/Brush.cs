using UnityEngine;

public class Brush : MonoBehaviour
{
    void Update ()
    {
        var ray = Camera.main.ScreenPointToRay(Input.mousePosition);
        transform.position = ray.origin + ray.direction * 0.5f;
    }
}
