Shader "ReactionDiffusion3D/Init"
{
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

			float rand(float n) { return frac(sin(n) * 43758.5453123); }

			float4 frag(v2f_volumeSlice In) : COLOR
			{
				return float4(rand(In.texcoord.x + In.texcoord.y * In.texcoord.x + In.texcoord.z * In.texcoord.y * In.texcoord.x), 0.0f, 0.0, 1.0f);
			}
			ENDCG
		}
	}
}
