Shader "ReactionDiffusion2D/Iteration"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_DiffusionRate ("DiffusionRate", Vector) = (1.0, 0.5, 0.0, 0.0)
		_KillRate ("KillRate", Float) = 0.06
		_FeedRate ("FeedRate", Float) = 0.037
		_Speed ("Speed", Float) = 400.0
	}
	SubShader
	{
		Lighting Off
		Cull Off ZWrite Off ZTest Always

		Pass
		{
			CGPROGRAM
			#include "UnityCG.cginc"
			#pragma vertex vert_img
			#pragma fragment frag
			
			sampler2D _MainTex;
			float4 _MainTex_TexelSize;
			float2 _DiffusionRate;
			float _KillRate;
			float _FeedRate;
			float _Speed;
			float _NumIterationsPerFrame;


			float2 computeLaplacian(float2 uv, float2 current)
			{
				// with diagonals.
				return (tex2D(_MainTex, uv + float2(_MainTex_TexelSize.x, 0.0)).xy +
						tex2D(_MainTex, uv - float2(_MainTex_TexelSize.x, 0.0)).xy +
						tex2D(_MainTex, uv + float2(0.0, _MainTex_TexelSize.y)).xy +
						tex2D(_MainTex, uv - float2(0.0, _MainTex_TexelSize.y)).xy) * 0.2f
					    +
					   (tex2D(_MainTex, uv + _MainTex_TexelSize).xy +
						tex2D(_MainTex, uv - _MainTex_TexelSize).xy +
						tex2D(_MainTex, uv + float2(_MainTex_TexelSize.x, -_MainTex_TexelSize.y)).xy +
						tex2D(_MainTex, uv - float2(_MainTex_TexelSize.x, -_MainTex_TexelSize.y)).xy) * 0.05f
						-
						current;
			}

			float4 frag(v2f_img In) : COLOR
			{
				float2 current = max(float2(0.0f, 0.0f), tex2D(_MainTex, In.uv).xy);

				// Compute diffusion.
				float2 laplacian = computeLaplacian(In.uv, current);
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
