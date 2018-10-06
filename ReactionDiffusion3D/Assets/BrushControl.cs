using System.Collections;
using System.Linq;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.Rendering;

[RequireComponent(typeof(ReactionDiffusionCube))]
public class BrushControl : MonoBehaviour
{
    private const float BrushRadiusMin = 0.001f;
    private const float BrushRadiusMax = 0.5f;

    [Range(BrushRadiusMin, BrushRadiusMax)]
    public float BrushRadius = 0.018f;

    public float BrushIntensity = 10.0f;
    
    public bool BrushEnabled { get; set; } = true;

    private void Update()
    {
        BrushRadius = Mathf.Clamp(BrushRadius + Input.mouseScrollDelta.y * 0.003f, BrushRadiusMin, BrushRadiusMax); 

        var ray = Camera.main.ScreenPointToRay(Input.mousePosition);
        Vector3 brushWorldPosition = ray.origin + ray.direction * 3.0f;

        float intensity = 0.0f;
        if (!EventSystem.current.IsPointerOverGameObject() && BrushEnabled)
        {
            if (Input.GetMouseButton(0))
                intensity = BrushIntensity;
            if (Input.GetMouseButton(2))
                intensity = -BrushIntensity;
        }

        GetComponent<ReactionDiffusionCube>().SetBrushProperties(brushWorldPosition, BrushEnabled ? BrushRadius : 0.0f, intensity);
    }
}
