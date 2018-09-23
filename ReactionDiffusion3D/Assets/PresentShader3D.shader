Shader "ReactionDiffusion3D/Present"
{
	Properties
	{
		//_ReactionDiffusionVolume ("Volume", 3D) = "white" {}
		_NoiseTexture ("Noise", 2D) = "white" {}

		// Linear attenuation coefficient. (for density 1)
		// Fraction of light scattered & absorbed / fraction that passes through.
		_ExtinctionFactor ("ExtinctionFactor", Float) = 100

		// Fraction of light scattered / fraction that passes through.
		_ScatteringFactor ("ScatteringFactor", Float) = 85

		// Higher value mean more directed scattering.
		_ScatteringAnisotropy ("ScatteringAnisotropy", Range(0.0, 1.0)) = 0.3

		_VolumeMarchStepSize ("VolumeMarchStepSize", Float) = 0.025
	}
	SubShader
	{
		ZWrite Off ZTest Always
		Blend One SrcAlpha // Alpha is extinction, color is premultiplied
		Cull Front

		Pass
		{
			Tags{ "LightMode" = "ForwardBase" "PassFlags" = "OnlyDirectional" }

			CGPROGRAM
			#include "UnityCG.cginc"
			#pragma vertex vert
			#pragma fragment frag
			
			sampler3D _ReactionDiffusionVolume;
			float4 _ReactionDiffusionVolume_TexelSize;
			sampler2D _NoiseTexture;
			float4 _NoiseTexture_TexelSize;

			float _ExtinctionFactor;
			float _ScatteringFactor;
			float _VolumeMarchStepSize;
			float _ScatteringAnisotropy;

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

			float SampleVolumeDensity(float3 volumePos)
			{
				return tex3Dlod(_ReactionDiffusionVolume, float4(volumePos, 0.0f)).y;
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

			void ComputeRay(v2f In, out float3 pos, out float3 dir, out float rayLength)
			{
				// Generate camera ray and place in volume.
				float3 cameraPosVolume = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1.0f)).xyz;
				dir = normalize(In.volumePos - cameraPosVolume);
				const float3 cubeExtent = float3(0.5f, 0.5f, 0.5f);
				pos = cameraPosVolume + cubeExtent;

				// Determine cut with box so we can shorten the ray.
				float2 boxIntersection = BoxIntersection(cameraPosVolume, dir, cubeExtent);

				// Add a random ray offset.
				float randomOffset = (tex2D(_NoiseTexture, In.vertex.xy * _NoiseTexture_TexelSize.xy).x + 0.1f) * _VolumeMarchStepSize;
				float rayStartOffset = randomOffset;
				rayLength = boxIntersection.y - randomOffset; // Maximal length to far box hit.
				if (IsOutsideUnitCube(pos)) // If outside, shorten ray to start of cube.
				{
					rayStartOffset += boxIntersection.x;
					rayLength -= boxIntersection.x; 
				}
				pos += dir * rayStartOffset;
			}

			float EvaluateHenyeyGreensteinPhaseFunction(float g, float3 toLightNorm, float3 evalDirNorm)
			{
				const float gSq = g * g;
				return (1.0f - gSq) * pow(1.0f + gSq - 2.0f * g * dot(toLightNorm, evalDirNorm), -3.0f / 2.0f) * 0.25; // dropped 1/pi factor
			}

			float4 frag(v2f In) : COLOR
			{
				float3 pos, dir;
				float maxRayLength;
				ComputeRay(In, pos, dir, maxRayLength);

				float hgPhase = EvaluateHenyeyGreensteinPhaseFunction(_ScatteringAnisotropy, dir, _WorldSpaceLightPos0.xyz);
				float4 accumScatteringTransmittance = float4(0.0f, 0.0f, 0.0f, 1.0f);
				const int maxNumSteps = min(128, (int)(maxRayLength / _VolumeMarchStepSize));
				for (int i = 0; i < maxNumSteps && accumScatteringTransmittance.a > 0.01; ++i)
				{
					pos += dir * _VolumeMarchStepSize;
					float density = SampleVolumeDensity(pos);

					// Henyey Greenstein phase function

					float sampleScattering = _ScatteringFactor * density * _VolumeMarchStepSize * hgPhase;

					// We walk from the camera through the volume.
					// The further we walk, the less relevant get our samples since less right reaches the viewer / more is absorbed on the way.
					// This is governed by beer/lambert absoroption law.
					float extinctionCoefficient = density * _ExtinctionFactor;
					float sampleTransmittance = exp(-extinctionCoefficient * _VolumeMarchStepSize);
					// Because it is so expensive we assume the light & density samples to be constant. However, we can integrate beers law over the step length!					
					// (http://advances.realtimerendering.com/s2015/index.html, Towards Unified and Physically-Based Volumetric Lighting in Frostbite)
					// Note that since our volume is non-homogenous we still need to split the integral - left the so far accumulated part, right the current sample
					accumScatteringTransmittance.rgb += accumScatteringTransmittance.a * sampleScattering + 
														(sampleScattering - sampleTransmittance * sampleScattering) / (extinctionCoefficient + 1e-5);
					accumScatteringTransmittance.a *= sampleTransmittance;
				}

				return float4(1.0f, 0.0f, 1.0f, 0.0f);
			}
			ENDCG
		}
	}
}
