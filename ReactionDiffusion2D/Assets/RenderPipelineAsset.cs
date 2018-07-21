using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;

namespace ReactionDiffusion2D
{
    [CreateAssetMenu(fileName = nameof(ReactionDiffusion2DRenderPipeline),
        menuName = "Rendering/" + nameof(ReactionDiffusion2DRenderPipeline), order = 1)]
    public class RenderPipelineAsset : UnityEngine.Experimental.Rendering.RenderPipelineAsset
    {
        public Shader ReactionDiffusionIterationShader;
        public Shader ReactionDiffusionBrushShader;
        public Shader PresentShader;
        public int NumIterationsPerFrame = 200;

        protected override IRenderPipeline InternalCreatePipeline() => new ReactionDiffusion2DRenderPipeline(this);
    }

    public class ReactionDiffusion2DRenderPipeline : UnityEngine.Experimental.Rendering.RenderPipeline
    {
        private readonly RenderTexture[] renderTexture = new RenderTexture[2] {null, null};
        private int frontRenderTextureIdx = 0;

        private readonly Material reactionDiffusionIterationMaterial;
        private readonly Material reactionDiffusionBrushMaterial;
        private readonly Material presentMaterial;

        public RenderPipelineAsset asset;


        public ReactionDiffusion2DRenderPipeline(RenderPipelineAsset asset)
        {
            reactionDiffusionIterationMaterial = new Material(asset.ReactionDiffusionIterationShader);
            reactionDiffusionBrushMaterial = new Material(asset.ReactionDiffusionBrushShader);
            presentMaterial = new Material(asset.PresentShader);
            this.asset = asset;
        }

        private void CreateRenderTextures(Camera camera)
        {
            for (int i = 0; i < 2; ++i)
            {
                renderTexture[i]?.Release();
                renderTexture[i] = new RenderTexture(camera.pixelWidth, camera.pixelHeight, 0);
                renderTexture[i].format = RenderTextureFormat.RGFloat;
                renderTexture[i].wrapMode = TextureWrapMode.Repeat;
                renderTexture[i].Create();
            }
        }

        private static void Swap(ref int a, ref int b)
        {
            int oldB = b;
            b = a;
            a = oldB;
        }

        private void PerformReactionDiffusionSimulation(CommandBuffer cmd, Camera camera)
        {
            if (camera != Camera.main)
                return;

            int backRenderTextureIdx = (frontRenderTextureIdx + 1) % 2;

            if ((renderTexture[0] == null || renderTexture[0].width != camera.pixelWidth ||
                renderTexture[0].height != camera.pixelHeight))
            {
                CreateRenderTextures(camera);
                cmd.SetRenderTarget(renderTexture[frontRenderTextureIdx]);
                cmd.ClearRenderTarget(false, true, new Color(1.0f, 0.0f, 0.0f, 0.0f));
            }

            foreach (var brush in Object.FindObjectsOfType<Brush2D>())
            {
                for (int i = 0; i < 16 && !brush.queuedStrokes.IsEmpty; ++i)
                {
                    Brush2D.BrushStroke stroke;
                    if (!brush.queuedStrokes.TryDequeue(out stroke))
                        continue;

                    var positionPixel = camera.WorldToScreenPoint(new Vector3(stroke.Position.x, stroke.Position.y));
                    float sizePixel = stroke.Radius * camera.pixelHeight / camera.orthographicSize * 0.5f;
                    reactionDiffusionBrushMaterial.SetVector("_BrushPositionPixel", new Vector2(positionPixel.x, positionPixel.y));
                    reactionDiffusionBrushMaterial.SetFloat("_BrushRadiusPixel", sizePixel);
                    reactionDiffusionBrushMaterial.SetFloat("_BrushIntensity", stroke.Intensity);

                    // TODO: Drawing a quad would be more efficient ofc.
                    cmd.Blit(null, renderTexture[frontRenderTextureIdx], reactionDiffusionBrushMaterial);
                }
            }

            if (!UnityEditor.EditorApplication.isPaused)
            {
                reactionDiffusionIterationMaterial.SetFloat("_NumIterationsPerFrame", asset.NumIterationsPerFrame);
                for (int i = 0; i < asset.NumIterationsPerFrame; ++i)
                {
                    Swap(ref frontRenderTextureIdx, ref backRenderTextureIdx);
                    cmd.Blit(renderTexture[backRenderTextureIdx], renderTexture[frontRenderTextureIdx], reactionDiffusionIterationMaterial);
                }
            }
        }

        private void RenderDefaultUnlit(ScriptableRenderContext context, Camera camera)
        {
            // Culling
            ScriptableCullingParameters cullingParams;
            if (!CullResults.GetCullingParameters(camera, out cullingParams))
                return; // How can this happen, what does it mean?
            cullingParams.cullingFlags = CullFlag.None;
            CullResults cullResults = new CullResults();
            CullResults.Cull(ref cullingParams, context, ref cullResults);

            var filterSettings = new FilterRenderersSettings(true);
            var drawSettings = new DrawRendererSettings(camera, new ShaderPassName("SRPDefaultUnlit"));

            // Drawing regular opaque
            drawSettings.sorting.flags = SortFlags.CommonOpaque;
            filterSettings.renderQueueRange = RenderQueueRange.opaque;
            context.DrawRenderers(cullResults.visibleRenderers, ref drawSettings, filterSettings);

            // Drawing regular transparent
            drawSettings.sorting.flags = SortFlags.CommonTransparent;
            filterSettings.renderQueueRange = RenderQueueRange.transparent;
            context.DrawRenderers(cullResults.visibleRenderers, ref drawSettings, filterSettings);
        }

        public override void Render(ScriptableRenderContext context, Camera[] cameras)
        {
            if (cameras.Length != 1)
                Debug.LogError("Only a single camera is supported!");
            Camera camera = cameras[0];
            context.SetupCameraProperties(camera, false);

            var cmd = new CommandBuffer();
            PerformReactionDiffusionSimulation(cmd, camera);
            cmd.Blit(renderTexture[frontRenderTextureIdx], camera.activeTexture, presentMaterial);
            context.ExecuteCommandBuffer(cmd);
            cmd.Release();

            RenderDefaultUnlit(context, camera);

            context.Submit();
        }
    }
}