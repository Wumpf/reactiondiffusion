using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

[RequireComponent(typeof(MeshRenderer))]
public class ReactionDiffusionCube : MonoBehaviour
{
    public Material BrushMaterial;
    public Material IterationMaterial;

    [Range(16, 512)]
    public int RenderTextureResolution = 256;

    // Must be even! Todo: Enforce, Expose
    [Range(2, 100)]
    public int NumIterationsPerFrame = 6;

    private readonly RenderTexture[] renderTexture = new RenderTexture[] {null, null};
    private MaterialPropertyBlock[,] materialPerSliceProperties;
    private CommandBuffer iterationCommandBuffer;
    private CommandBuffer brushCommandBuffer;

    private const CameraEvent volumeUpdateEvent = CameraEvent.BeforeForwardOpaque;

    public void EnableSimulation(bool enable)
    {
        if (enable)
            Camera.main.AddCommandBuffer(volumeUpdateEvent, iterationCommandBuffer);
        else
            Camera.main.RemoveCommandBuffer(volumeUpdateEvent, iterationCommandBuffer);
    }

    private void OnValidate()
    {
        if (NumIterationsPerFrame % 2 != 0)
            NumIterationsPerFrame++;
        IterationMaterial?.SetFloat("_NumIterationsPerFrame", NumIterationsPerFrame);
    }

    private void CreateVolumes()
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
            renderTexture[i].wrapModeU = TextureWrapMode.Repeat;
            renderTexture[i].wrapModeV = TextureWrapMode.Repeat;
            renderTexture[i].wrapModeW = TextureWrapMode.Repeat;
            renderTexture[i].filterMode = FilterMode.Bilinear;
        }
   
        materialPerSliceProperties = new MaterialPropertyBlock[2, RenderTextureResolution];
        for (int texture = 0; texture < 2; ++texture)
        {
            for (int slice = 0; slice < RenderTextureResolution; ++slice)
            {
                materialPerSliceProperties[texture, slice] = new MaterialPropertyBlock();
                materialPerSliceProperties[texture, slice].SetTexture("_MainTex", renderTexture[texture]);
                materialPerSliceProperties[texture, slice].SetFloat("_VolumeDepth", (slice + 0.5f) / RenderTextureResolution);
            }
        }
    }

    private void AddVolumeUpdateToCommandBuffer(CommandBuffer cmdBuffer, int volumeIndex, Material material)
    {
        // Unless CommandBuffer.Blit we know that we fill the entire screen, so we just do n fullscreen triangles and let the shader figure the rest out.
        // Haven't found out how to do multiple viewport rendering (SV_ViewportArrayIndex style) though, then I could do this with less (a single?) draw calls.
        for(int slice=0; slice<RenderTextureResolution; ++slice)
        {
            cmdBuffer.SetRenderTarget(renderTexture[volumeIndex], 0, CubemapFace.Unknown, slice);
            cmdBuffer.DrawProcedural(Matrix4x4.identity, material, 0, MeshTopology.Triangles, 3, 1, materialPerSliceProperties[(volumeIndex + 1) % 2, slice]);
        }
    }

    private IEnumerator DrawBrush()
    {
        BrushMaterial.SetVector("_BrushPositionSize", new Vector4(0.5f, 0.5f, 0.5f, 0.2f));
        Camera.main.AddCommandBuffer(volumeUpdateEvent, brushCommandBuffer);
        
        yield return new WaitForEndOfFrame();
        Camera.main.RemoveCommandBuffer(volumeUpdateEvent, brushCommandBuffer);
    }

    private IEnumerator InitSimulation()
    {
        yield return new WaitForEndOfFrame();

        var initCommandBuffer = new CommandBuffer();
        initCommandBuffer.name = "Init";
        foreach (RenderTexture target in renderTexture)
        {
            for(int slice=0; slice<RenderTextureResolution; ++slice)
            {
                initCommandBuffer.SetRenderTarget(target, 0, CubemapFace.Unknown, slice);
                initCommandBuffer.ClearRenderTarget(false, true, new Color(1.0f, 0.0f, 0.0f, 0.0f));
            }
        }
        Camera.main.AddCommandBuffer(volumeUpdateEvent, initCommandBuffer);

        yield return new WaitForEndOfFrame();
        Camera.main.RemoveCommandBuffer(volumeUpdateEvent, initCommandBuffer);
        Camera.main.AddCommandBuffer(volumeUpdateEvent, iterationCommandBuffer);
    }

    private IEnumerator Start()
    {
        CreateVolumes();

        // Setup iterations.
        iterationCommandBuffer = new CommandBuffer();
        iterationCommandBuffer.name = "Volume Iteration";
        for(int i=0; i<NumIterationsPerFrame; ++i)
        {
            int updatedVolumeIndex = (i+1) % 2;
            AddVolumeUpdateToCommandBuffer(iterationCommandBuffer, updatedVolumeIndex, IterationMaterial);
        }
        IterationMaterial.SetFloat("_NumIterationsPerFrame", NumIterationsPerFrame);
        GetComponent<MeshRenderer>().material.SetTexture("_ReactionDiffusionVolume", renderTexture[0]);

        // Setup brush.
        brushCommandBuffer = new CommandBuffer();
        brushCommandBuffer.name = "Brush";
        AddVolumeUpdateToCommandBuffer(brushCommandBuffer, 0, BrushMaterial);

        return InitSimulation();
    }

    private void Update()
    {
        if (Input.GetMouseButton(0))
            StartCoroutine(DrawBrush());
    }
}
