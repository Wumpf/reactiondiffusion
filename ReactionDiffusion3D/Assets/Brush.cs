using UnityEngine;
using UnityEngine.EventSystems;

public class Brush : MonoBehaviour
{
    public ReactionDiffusionCube RDCube;

    void Update ()
    {
        var ray = Camera.main.ScreenPointToRay(Input.mousePosition);
        transform.position = ray.origin + ray.direction * 0.5f;

        if (Input.GetMouseButton(0) && !EventSystem.current.IsPointerOverGameObject())
            RDCube.DrawBrush(transform.position);
    }
}
