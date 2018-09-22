Shader "ReactionDiffusion2D/Brush"
{
	SubShader
	{
		Cull Off ZWrite Off ZTest Always
		Blend One One

		Pass
		{
			CGPROGRAM
			#include "UnityCG.cginc"
			#pragma vertex vert_img
			#pragma fragment frag

			float2 _BrushPositionPixel;
			float _BrushRadiusPixel;
			float _BrushIntensity;

			float4 frag(v2f_img In) : COLOR
			{
				float2 toBrushCenter = _BrushPositionPixel - In.uv * _ScreenParams.xy;
				float brushDist = length(toBrushCenter);
				clip(_BrushRadiusPixel - brushDist);
				float brushIntensity = 1.0f - brushDist / _BrushRadiusPixel;
				brushIntensity *= brushIntensity;

				return float4(0.0, brushIntensity * unity_DeltaTime.x * _BrushIntensity, 0.0, 1.0);
			}
			ENDCG
		}
	}
}
