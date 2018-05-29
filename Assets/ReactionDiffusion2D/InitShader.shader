Shader "ReactionDiffusion2D/Init"
{
	Properties
	{
		_AspectRatio("AspectRatio", Float) = 1.0
	}
	SubShader
	{
		Cull Off ZWrite Off ZTest Always

		Pass
		{
			CGPROGRAM
			#include "UnityCG.cginc"
			#pragma vertex vert_img
			#pragma fragment frag

			float _AspectRatio;

			float4 frag(v2f_img In) : COLOR
			{
				float2 toMid = float2(0.5f, 0.5f) - In.uv; //(iResolution.xy * 0.5 - fragCoord) / iResolution.y;
				toMid.x *= _AspectRatio;
				//toMid += sin(atan2(toMid.x, toMid.y)*10.0) * 0.01; // Wobble circle a bit to get the desired effects faster.
				float midDistSq = dot(toMid, toMid);
				float initVal = midDistSq; //pow(sin(midDistSq * 40.0) * 0.5 + 0.5, 5.0);

				return float4(1.0, initVal, 0.0, 1.0);
			}
			ENDCG
		}
	}
}
