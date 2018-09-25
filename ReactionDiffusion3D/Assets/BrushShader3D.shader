Shader "ReactionDiffusion3D/Brush"
{
	SubShader
	{
		Cull Off ZWrite Off ZTest Always
		Blend One One

		Pass
		{
			CGPROGRAM
			#include "UnityCG.cginc"
			#include "VolumeSlice.cginc"
			#pragma vertex vert_volumeSlice
			#pragma fragment frag

			sampler2D _NoiseTexture;
			float4 _NoiseTexture_TexelSize;
			float4 _BrushPositionSize;
			float _BrushIntensity;


			float4 frag(v2f_volumeSlice In) : COLOR
			{
				float3 toBrushCenter = _BrushPositionSize.xyz - In.texcoord;
				float brushDist = length(toBrushCenter);
				clip(_BrushPositionSize.w - brushDist);
				float brushFade = 1.0f - brushDist / _BrushPositionSize.w;
				brushFade *= brushFade;

				return float4(0.0, brushFade * unity_DeltaTime.x * _BrushIntensity, 0.0, 1.0); // todo don't allow negative values
			}
			ENDCG
		}
	}
}
