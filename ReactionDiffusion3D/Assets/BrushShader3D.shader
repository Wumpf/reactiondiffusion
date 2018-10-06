Shader "ReactionDiffusion3D/Brush"
{
	SubShader
	{
		Cull Off ZWrite Off ZTest Always

		Pass
		{
			CGPROGRAM
			#include "UnityCG.cginc"
			#include "VolumeSlice.cginc"
			#pragma vertex vert_volumeSlice
			#pragma fragment frag

			sampler3D _MainTex;
			float4 _NoiseTexture_TexelSize;
			float4 _BrushPositionSize;
			float _BrushIntensity;


			float4 frag(v2f_volumeSlice In) : COLOR
			{
				float3 toBrushCenter = _BrushPositionSize.xyz - In.texcoord;
				float brushDist = length(toBrushCenter);
				clip(_BrushPositionSize.w - brushDist);
				float brushFade = saturate(1.0f - brushDist / _BrushPositionSize.w);
				brushFade *= brushFade;

				float2 current = tex3D(_MainTex, In.texcoord).xy;
				float brush = brushFade * unity_DeltaTime.x * _BrushIntensity;
				return float4(current.x, clamp(current.y + brush, 0.0f, 5.0f), 0.0f, 0.0f);
			}
			ENDCG
		}
	}
}
