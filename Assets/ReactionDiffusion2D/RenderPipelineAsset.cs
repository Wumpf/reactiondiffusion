using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;

namespace ReactionDiffusion2D
{
    [CreateAssetMenu(fileName = nameof(RenderPipeline),
        menuName = "Rendering/" + nameof(RenderPipeline), order = 1)]
    public class RenderPipelineAsset : UnityEngine.Experimental.Rendering.RenderPipelineAsset
    {
        public Shader ReactionDiffusionIterationShader;
        public Shader ReactionDiffusionInitShader;
        public Shader PresentShader;

        protected override IRenderPipeline InternalCreatePipeline() => new RenderPipeline(this);
    }

    public class RenderPipeline : UnityEngine.Experimental.Rendering.RenderPipeline
    {
        private readonly RenderTexture[] renderTexture = new RenderTexture[2] {null, null};
        private int frontRenderTextureIdx = 0;

        private readonly Material reactionDiffusionIterationMaterial;
        private readonly Material reactionDiffusionInitMaterial;
        private readonly Material presentMaterial;

        public int NumIterationsPerFrame = 20;

        public RenderPipeline(RenderPipelineAsset asset)
        {
            reactionDiffusionIterationMaterial = new Material(asset.ReactionDiffusionIterationShader);
            reactionDiffusionInitMaterial = new Material(asset.ReactionDiffusionInitShader);
            presentMaterial = new Material(asset.PresentShader);
        }

        private void CreateRenderTextures(Camera camera)
        {
            for (int i = 0; i < 2; ++i)
            {
                renderTexture[i]?.Release();
                renderTexture[i] = new RenderTexture(camera.pixelWidth, camera.pixelHeight, 0);
                renderTexture[i].format = RenderTextureFormat.RGFloat;
                renderTexture[i].Create();
            }
        }

        private static void Swap(ref int a, ref int b)
        {
            int oldB = b;
            b = a;
            a = oldB;
        }

        public override void Render(ScriptableRenderContext context, Camera[] cameras)
        {
            var cmd = new CommandBuffer();
            int backRenderTextureIdx = (frontRenderTextureIdx + 1) % 2;

            if (renderTexture[0] == null || renderTexture[0].width != cameras[0].pixelWidth ||
                renderTexture[0].height != cameras[0].pixelHeight)
            {
                CreateRenderTextures(cameras[0]);
                reactionDiffusionInitMaterial.SetFloat("_AspectRatio", ((float)renderTexture[0].width) / renderTexture[0].height);
                cmd.Blit(renderTexture[backRenderTextureIdx], renderTexture[frontRenderTextureIdx], reactionDiffusionInitMaterial);
            }

            if (!UnityEditor.EditorApplication.isPaused)
            {
                for (int i = 0; i < NumIterationsPerFrame; ++i)
                {
                    Swap(ref frontRenderTextureIdx, ref backRenderTextureIdx);
                    cmd.Blit(renderTexture[backRenderTextureIdx], renderTexture[frontRenderTextureIdx], reactionDiffusionIterationMaterial);
                }
            }

            cmd.Blit(renderTexture[frontRenderTextureIdx], cameras[0].activeTexture, presentMaterial);

            context.ExecuteCommandBuffer(cmd);
            cmd.Release();
            context.Submit();
        }
    }
}