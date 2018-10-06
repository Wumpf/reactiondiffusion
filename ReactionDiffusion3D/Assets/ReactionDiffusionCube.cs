using System.Collections;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.Rendering;
using System.Linq;

[RequireComponent(typeof(MeshRenderer))]
public class ReactionDiffusionCube : MonoBehaviour
{
    public Material BrushMaterial;
    public Material IterationMaterial;
    private Material PresentMaterial => GetComponent<MeshRenderer>().material;

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
            renderTexture[i].name = "Reaction Diffusion Volume " + i;
            renderTexture[i].wrapModeU = TextureWrapMode.Repeat;
            renderTexture[i].wrapModeV = TextureWrapMode.Repeat;
            renderTexture[i].wrapModeW = TextureWrapMode.Repeat;
            renderTexture[i].filterMode = FilterMode.Bilinear;
            renderTexture[i].Create();
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
   
    public void SetBrushProperties(Vector3 brushWorldPosition, float brushSize, float activeIntensity)
    {
        float uniformScale = transform.lossyScale.x;
        var brushPosition = brushWorldPosition / uniformScale + new Vector3(0.5f, 0.5f, 0.5f);
        var brushPositionSize = new Vector4(brushPosition.x, brushPosition.y, brushPosition.z, brushSize);
        PresentMaterial.SetVector("_BrushPositionSize", brushPositionSize);
        if (activeIntensity != 0.0f)
        {
            BrushMaterial.SetVector("_BrushPositionSize", brushPositionSize);
            BrushMaterial.SetFloat("_BrushIntensity", activeIntensity);
            if (Camera.main.GetCommandBuffers(volumeUpdateEvent).All(x => x.name != brushCommandBuffer.name))
                Camera.main.AddCommandBuffer(volumeUpdateEvent, brushCommandBuffer);
        }
        else
            Camera.main.RemoveCommandBuffer(volumeUpdateEvent, brushCommandBuffer);
    }

    private IEnumerator InitSimulation()
    {
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

        // Setup brush.
        brushCommandBuffer = new CommandBuffer();
        brushCommandBuffer.name = "Brush";
        BrushMaterial.SetTexture("_MainTex", renderTexture[1]);
        AddVolumeUpdateToCommandBuffer(brushCommandBuffer, 0, BrushMaterial);

        return InitSimulation();
    }

    private void Update()
    {
        // Set texture every frame so we get don't loose it if the shader reloads.
        // Note: For some reason we loose our simulation state if we reload while the simulation is active. Not sure why and can't find a callback for shader reload.
        PresentMaterial.SetTexture("_ReactionDiffusionVolume", renderTexture[0]);
    }
}
