Shader "ReactionDiffusion3D/Iteration"
{
	Properties
	{
		_MainTex ("Texture", 3D) = "white" {}
		_DiffusionRate ("DiffusionRate", Vector) = (1.0, 0.5, 0.0, 0.0)
		_KillRate ("KillRate", Float) = 0.062
		_FeedRate ("FeedRate", Float) = 0.0545
		_Speed ("Speed", Float) = 100
	}
	SubShader
	{
		Lighting Off
		Cull Off ZWrite Off ZTest Always

		Pass
		{
			CGPROGRAM
			#include "UnityCG.cginc"
			#include "VolumeSlice.cginc"
			#pragma vertex vert_volumeSlice
			#pragma fragment frag
			
			sampler3D _MainTex;
			float4 _MainTex_TexelSize;
			float2 _DiffusionRate;
			float _KillRate;
			float _FeedRate;
			float _Speed;
			float _NumIterationsPerFrame;


			float2 computeLaplacian(float3 uv, float2 current)
			{
				float3 texelSize = _MainTex_TexelSize.xyy; // _TexelSioze doesn't work quite for 3d textures.

				return (tex3D(_MainTex, uv + float3(texelSize.x, 0.0f, 0.0f)).xy +
						tex3D(_MainTex, uv - float3(texelSize.x, 0.0f, 0.0f)).xy +
						tex3D(_MainTex, uv + float3(0.0f, texelSize.y, 0.0f)).xy +
						tex3D(_MainTex, uv - float3(0.0f, texelSize.y, 0.0f)).xy +
						tex3D(_MainTex, uv + float3(0.0f, 0.0f, texelSize.z)).xy +
						tex3D(_MainTex, uv - float3(0.0f, 0.0f, texelSize.z)).xy) / 6.0f
					- current;
			}

			float4 frag(v2f_volumeSlice In) : COLOR
			{
				float2 current = max(float2(0.0f, 0.0f), tex3D(_MainTex, In.texcoord).xy);

				// Compute diffusion.
				float2 laplacian = computeLaplacian(In.texcoord, current);
				float2 diffusion = _DiffusionRate * laplacian;

				// Compute reaction.
				float u = current.x;
				float v = current.y;
				float reactionU = -u * v * v + _FeedRate * (1.0f - u);
				float reactionV = u * v * v - (_FeedRate + _KillRate) * v;

				// Apply using simple forward Euler.
				float2 newValues = current + (diffusion + float2(reactionU, reactionV)) * (_Speed * unity_DeltaTime.x / _NumIterationsPerFrame);

				return float4(newValues, 0.0, 1.0);
			}

			ENDCG
		}
	}
}
