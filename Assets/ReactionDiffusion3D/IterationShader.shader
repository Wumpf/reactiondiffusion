Shader "ReactionDiffusion3D/Iteration"
{
	Properties
	{
		_MainTex ("Texture", 3D) = "white" {}
		_DiffusionRate ("DiffusionRate", float) = (1.0, 0.5, 0.0, 0.0)
		_KillRate ("KillRate", Float) = 0.062
		_FeedRate ("FeedRate", Float) = 0.0545
		_Speed ("Speed", Float) = 10.0
	}
	SubShader
	{
		Lighting Off

		Pass
		{
			CGPROGRAM
			#include "UnityCustomRenderTexture.cginc"

			#pragma vertex CustomRenderTextureVertexShader
			#pragma fragment frag
			
			sampler2D _MainTex;
			float4 _MainTex_TexelSize;
			float2 _DiffusionRate;
			float _KillRate;
			float _FeedRate;
			float _Speed;

			float rand(float n) { return frac(sin(n) * 43758.5453123); }

			float4 frag(v2f_customrendertexture In) : COLOR
			{
				return float4(rand(In.globalTexcoord.x + In.globalTexcoord.y * In.globalTexcoord.x + In.globalTexcoord.z * In.globalTexcoord.y * In.globalTexcoord.x), 0.0f, 0.0, 1.0f);
			}
			ENDCG
		}
	}
}
