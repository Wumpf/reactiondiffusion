Shader "ReactionDiffusion3D/Iteration"
{
	Properties
	{
		_MainTex ("Texture", 3D) = "white" {}
		_DiffusionRate ("DiffusionRate", Vector) = (1.0, 0.5, 0.0, 0.0)
		_KillRate ("KillRate", Float) = 0.062
		_FeedRate ("FeedRate", Float) = 0.0545
		_Speed ("Speed", Float) = 80
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
				float3 texelSize = _MainTex_TexelSize.xyy; // _TexelSize doesn't work quite for 3d textures.

		/*		return (tex3D(_MainTex, uv + float3(texelSize.x, 0.0f, 0.0f)).xy +
						tex3D(_MainTex, uv - float3(texelSize.x, 0.0f, 0.0f)).xy +
						tex3D(_MainTex, uv + float3(0.0f, texelSize.y, 0.0f)).xy +
						tex3D(_MainTex, uv - float3(0.0f, texelSize.y, 0.0f)).xy +
						tex3D(_MainTex, uv + float3(0.0f, 0.0f, texelSize.z)).xy +
						tex3D(_MainTex, uv - float3(0.0f, 0.0f, texelSize.z)).xy)
					- current * 6.0f;*/

				float3 texelSizeHalf = texelSize * 0.5f;

				// Sampling on the corners of the texel cube. Means that each sample samples 8 neighbor texels each with a weight of 0.25
				// This results in 27 sampled texels, four different kinds with different weights.
				// Leading to a 3d laplace filter with diagonals.
				return (tex3D(_MainTex, uv + float3(texelSizeHalf.x, texelSizeHalf.y, texelSizeHalf.z)).xy +
					tex3D(_MainTex, uv + float3(-texelSizeHalf.x, texelSizeHalf.y, texelSizeHalf.z)).xy +
					tex3D(_MainTex, uv + float3(-texelSizeHalf.x, -texelSizeHalf.y, texelSizeHalf.z)).xy +
					tex3D(_MainTex, uv + float3(texelSizeHalf.x, -texelSizeHalf.y, texelSizeHalf.z)).xy +
					tex3D(_MainTex, uv + float3(texelSizeHalf.x, texelSizeHalf.y, -texelSizeHalf.z)).xy +
					tex3D(_MainTex, uv + float3(-texelSizeHalf.x, texelSizeHalf.y, -texelSizeHalf.z)).xy +
					tex3D(_MainTex, uv + float3(-texelSizeHalf.x, -texelSizeHalf.y, -texelSizeHalf.z)).xy +
					tex3D(_MainTex, uv + float3(texelSizeHalf.x, -texelSizeHalf.y, -texelSizeHalf.z)).xy)
					- current * 8.0f;
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
