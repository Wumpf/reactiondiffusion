Shader "ReactionDiffusion3D/Present"
{
	Properties
	{
		_ReactionDiffusionVolume ("Texture", 3D) = "white" {}
	}
	SubShader
	{
		//ZWrite Off ZTest Always

		Pass
		{
			CGPROGRAM
			#include "UnityCG.cginc"
			#pragma vertex vert
			#pragma fragment frag
			
			sampler3D _ReactionDiffusionVolume;
			float4 _ReactionDiffusionVolume_TexelSize;

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float3 volumePos : TEXCOORD0;
			};

			v2f vert(appdata_base v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.volumePos = v.vertex.xyz;
				return o;
			}

			float2 SampleVolume(float3 volumePos)
			{
				return tex3Dlod(_ReactionDiffusionVolume, float4(volumePos, 0.0f)).xy;
			}

			float4 frag(v2f In) : COLOR
			{
				float3 cameraPosVolume = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1.0f)).xyz;
				float3 dir = normalize(In.volumePos - cameraPosVolume);

				const float stepSize = 0.02f;
				dir *= stepSize;

				float3 pos = In.volumePos + float3(0.5f, 0.5f, 0.5f);
				
				float value = 0.0f;
				float accumulatedOpacity = 0.0f;

				for (int i = 0; i < 128; ++i)
				{
					float2 sampledVolume = SampleVolume(pos);
					float sampleOpacity = sampledVolume.y * 1.8f; // dot(sampledVolume, sampledVolume) * 4.0f;
					float sampleValue = sampledVolume.y;

					sampleOpacity *= stepSize;

					accumulatedOpacity = sampleOpacity + (1.0f - sampleOpacity) * accumulatedOpacity;
					value              += (1.0f - accumulatedOpacity) * (sampleValue * sampleOpacity);
					
					pos += dir;

					if (accumulatedOpacity > 0.99f ||
						pos.x < 0.0f || pos.x > 1.0f || pos.y < 0.0f || pos.y > 1.0f || pos.z < 0.0f || pos.z > 1.0f)
					{
						return float4(value.xxx*accumulatedOpacity * 10.0f, 1.0f);
						//return float4(value*accumulatedOpacity, 0.0f, 1.0f);
					}
				}

				// Error: Didn't have enough steps!
				return float4(1.0f, 0.0f, 1.0f, 0.0f);

				//clip(value*accumulatedOpacity - 0.001f);
				//return float4(In.volumePos, 0.0f);
				//return float4(SampleVolume().xy, 0.0f, 1.0f);
			}
			ENDCG
		}
	}
}
