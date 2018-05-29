Shader "ReactionDiffusion2D/Present"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
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
			
			sampler2D _MainTex;

			float4 frag(v2f_img In) : COLOR
			{
				float2 values = tex2D(_MainTex, In.uv).xy;
				//return float4(values, 0, 0);

				float displayedValue = values.x;

				// Sigmoid-like function for nice edges
				const float edginess = 20.0;
				float sigmoid = 1.0 / (1.0 + exp(-displayedValue * edginess + edginess * 0.5));

				return float4(sigmoid.xxx, 1.0f);
			}
			ENDCG
		}
	}
}
