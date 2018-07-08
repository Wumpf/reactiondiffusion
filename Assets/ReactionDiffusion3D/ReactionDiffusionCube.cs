using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[RequireComponent(typeof(MeshRenderer))]
public class ReactionDiffusionCube : MonoBehaviour
{
    public Material InitMaterial;
    public Material IterationMaterial;

    [Range(16, 512)]
    public int RenderTextureResolution = 128;

    private readonly RenderTexture[] renderTexture = new RenderTexture[2] {null, null};
    private int frontRenderTextureIdx = 0;

    private void Start()
    {
        for(int i=0; i<2; ++i)
        {
            renderTexture[i] = new RenderTexture(new RenderTextureDescriptor()
            {
                width = RenderTextureResolution,
                height = RenderTextureResolution,
                volumeDepth = RenderTextureResolution,
                colorFormat = RenderTextureFormat.RGFloat,
                dimension = TextureDimension.Tex3D,
                msaaSamples = 1,
            });
            renderTexture[i].Create();
            renderTexture[i].name = "Reaction Diffusion Volume " + i;
        }
        
        // Unless CommandBuffer.Blit we know that we fill the entire screen, so we just do n fullscreen triangles and let the shader figure the rest out.
        // Haven't found out how to do multiple viewport rendering (SV_ViewportArrayIndex style) though, then I could do this with less (a single?) draw calls.
        var initCmdBuffer = new CommandBuffer();
        initCmdBuffer.name = "Init Volume";
        for(int slice=0; slice<RenderTextureResolution; ++slice)
        {
            var materialProperties = new MaterialPropertyBlock();
            materialProperties.SetFloat("_VolumeDepth", ((float) slice) / (RenderTextureResolution - 1));

            initCmdBuffer.SetRenderTarget(renderTexture[frontRenderTextureIdx], 0, CubemapFace.Unknown, slice);
            initCmdBuffer.DrawProcedural(Matrix4x4.identity, InitMaterial, 0, MeshTopology.Triangles, 3, 1, materialProperties);
        }

        // todo: remove again
        Camera.main.AddCommandBuffer(CameraEvent.BeforeImageEffects, initCmdBuffer);
    }

    private void ReactionDiffusionIteration()
    {
    }

    void Update ()
    {
        ReactionDiffusionIteration();
        GetComponent<MeshRenderer>().material.SetTexture("_ReactionDiffusionVolume", renderTexture[frontRenderTextureIdx]);

        // Spinning cube!!111!!!
        transform.Rotate(0.0f, Time.deltaTime*10.0f, 0.0f);
    }
}
