Shader "ReactionDiffusion3D/Present"
{
	Properties
	{
		//_ReactionDiffusionVolume ("Volume", 3D) = "white" {}
		_NoiseTexture("Noise", 2D) = "white" {}
	}
	SubShader
	{
		//ZWrite Off ZTest Always
		Cull Front

		Pass
		{
			CGPROGRAM
			#include "UnityCG.cginc"
			#pragma vertex vert
			#pragma fragment frag
			
			sampler3D _ReactionDiffusionVolume;
			float4 _ReactionDiffusionVolume_TexelSize;
			sampler2D _NoiseTexture;
			float4 _NoiseTexture_TexelSize;

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

			float GetOpacity(float2 sampledVolume)
			{
				return sampledVolume.y * 1.8f;
			}

			float3 ComputeGradient(float3 pos, float posOpacity, float stepSize)
			{
				float E = GetOpacity(SampleVolume(pos + float3(stepSize, 0, 0)));
				float N = GetOpacity(SampleVolume(pos + float3(0, stepSize, 0)));
				float U = GetOpacity(SampleVolume(pos + float3(0, 0, stepSize)));
				return float3(E - posOpacity, N - posOpacity, U - posOpacity) / stepSize;
			}

			// Box intersection by iq
			// http://www.iquilezles.org/www/articles/boxfunctions/boxfunctions.htm
			float2 BoxIntersection(float3 ro, float3 rd, float3 boxSize)
			{
				float3 m = 1.0 / rd;
				float3 n = m * ro;
				float3 k = abs(m)*boxSize;

				float3 t1 = -n - k;
				float3 t2 = -n + k;

				float tN = max(max(t1.x, t1.y), t1.z);
				float tF = min(min(t2.x, t2.y), t2.z);

				if (tN > tF || tF < 0.0f) return float2(-1.0f, -1.0f); // no intersection

				//outNormal = -sign(rdd)*step(t1.yzx, t1.xyz)*step(t1.zxy, t1.xyz);

				return float2(tN, tF);
			}

			bool IsOutsideUnitCube(float3 pos)
			{
				return pos.x < 0.0f || pos.x > 1.0f || pos.y < 0.0f || pos.y > 1.0f || pos.z < 0.0f || pos.z > 1.0f;
			}

			float4 frag(v2f In) : COLOR
			{
				float3 cameraPosVolume = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1.0f)).xyz;
				float3 dir = normalize(In.volumePos - cameraPosVolume);

				const float stepSize = 0.025f;
				dir *= stepSize;

				const float3 cubeExtent = float3(0.5f, 0.5f, 0.5f);
				float3 pos = cameraPosVolume + cubeExtent;
				if (IsOutsideUnitCube(pos))
					pos += BoxIntersection(cameraPosVolume, dir, cubeExtent).x * dir;

				// Random offset
				float offset = tex2D(_NoiseTexture, In.vertex.xy * _NoiseTexture_TexelSize.xy).x + 0.1f;
				pos += dir * offset;

				float3 accumulatedColor = 0.0f;
				float accumulatedOpacity = 0.0f;

				for (int i = 0; i < 128; ++i)
				{
					pos += dir;
					float2 sampledVolume = SampleVolume(pos);
					float sampleOpacity = GetOpacity(sampledVolume);
					//float sampleValue = sampledVolume.y;

					float3 gradient = ComputeGradient(pos, sampleOpacity, stepSize);
					float gradientLenSq = dot(gradient, gradient);
					//if (gradientLenSq > 0.05f)
					//{
					//	float3 normal = gradient * rsqrt(gradientLenSq);
					//}
					float3 sampleColor = abs(gradient);
					//float lighting = saturate(dot(gradient * 10.0f, normalize(float3(1.0f, 1.0f, 0.0f))));
					//float3 sampleColor = sampleOpacity * lighting;


					sampleOpacity *= stepSize;
					accumulatedOpacity = sampleOpacity + (1.0f - sampleOpacity) * accumulatedOpacity;
					float sampleWeight = (1.0f - accumulatedOpacity) * sampleOpacity;
					accumulatedColor += sampleWeight * sampleColor;

					if (accumulatedOpacity > 0.99f || IsOutsideUnitCube(pos))
					{
						return float4(accumulatedColor*accumulatedOpacity, 1.0f);
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
