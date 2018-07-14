Shader "ReactionDiffusion3D/Init"
{
	Properties
	{
		_NoiseTexture("Noise", 2D) = "white" {}
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

			sampler2D _NoiseTexture;
			float4 _NoiseTexture_TexelSize;


			float GetRand(float3 n)
			{
				return (tex2D(_NoiseTexture, n.xy).x +
						tex2D(_NoiseTexture, n.yz).y +
						tex2D(_NoiseTexture, n.zx).z) / 3.0f;
			}

			float4 frag(v2f_volumeSlice In) : COLOR
			{
				float rand = GetRand(In.texcoord);
				//return _VolumeDepth.xxxx;
				//return float4(1.0f, pseudoRand, 0.0, 1.0f);

				float3 toMid = float3(0.5f, 0.5f, 0.5f) - In.texcoord;
				float midDistSq = dot(toMid, toMid);
				float initVal = midDistSq * (rand + 0.5f); // max(0.0f, midDistSq * pseudoRand);
				return float4(1.0f, initVal, 0.0, 1.0);
			}
			ENDCG
		}
	}
}
