using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

[ExecuteInEditMode]
public class RenderPipelineSelector : MonoBehaviour
{
    public UnityEngine.Experimental.Rendering.RenderPipelineAsset Pipeline;

    private void OnValidate()
    {
        UnityEngine.Rendering.GraphicsSettings.renderPipelineAsset = Pipeline;
    }

    private void Awake()
    {
        UnityEngine.Rendering.GraphicsSettings.renderPipelineAsset = Pipeline;
        EditorApplication.playModeStateChanged += (_) =>
        {
            UnityEngine.Rendering.GraphicsSettings.renderPipelineAsset = null;
            UnityEngine.Rendering.GraphicsSettings.renderPipelineAsset = Pipeline;
        };
    }
}