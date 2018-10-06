Shader "ReactionDiffusion3D/Present"
{
	Properties
	{
		//_ReactionDiffusionVolume ("Volume", 3D) = "white" {}
		_NoiseTexture ("Noise", 3D) = "white" {}

		// Linear attenuation coefficient. (for density 1)
		// Fraction of light scattered & absorbed / fraction that passes through.
		_ExtinctionFactor ("ExtinctionFactor", Float) = 100

		// Fraction of light scattered / fraction that passes through.
		_ScatteringFactor ("ScatteringFactor", Float) = 85

		// Higher value mean more directed scattering.
		_ScatteringAnisotropy ("ScatteringAnisotropy", Range(0.0, 1.0)) = 0.3
		_ScatterAmbient("ScatterAmbient", Float) = 0.08

		_VolumeMarchStepSize ("VolumeMarchStepSize", Float) = 0.025
		_VolumeMarchStepSize_ShadowRay ("VolumeMarchStepSize_ShadowRay", Float) = 0.05
	}
	SubShader
	{
		//ZWrite Off ZTest Always
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
			sampler3D _NoiseTexture;
			float4 _NoiseTexture_TexelSize;

			float _ExtinctionFactor;
			float _ScatteringFactor;

			float _ScatteringAnisotropy;
			float _ScatterAmbient;

			float _VolumeMarchStepSize;
			float _VolumeMarchStepSize_ShadowRay;

			float4 _BrushPositionSize;

			static const float3 cubeExtent = float3(0.501f, 0.501f, 0.501f);
			static const int maxNumRayMarchSteps = 128;
			static const int maxNumRayMarchSteps_Shadow = 32;

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
			float2 BoxIntersection(float3 ro, float3 rd, float3 boxSize, out float3 outNormal)
			{
				float3 m = 1.0 / rd;
				float3 n = m * ro;
				float3 k = abs(m)*boxSize;

				float3 t1 = -n - k;
				float3 t2 = -n + k;

				float tN = max(max(t1.x, t1.y), t1.z);
				float tF = min(min(t2.x, t2.y), t2.z);

				if (tN > tF || tF < 0.0f) return float2(-1.0f, -1.0f); // no intersection

				outNormal = -sign(rd)*step(t1.yzx, t1.xyz)*step(t1.zxy, t1.xyz);
				return float2(tN, tF);
			}
			// Sphere intersection by iq
			// http://www.iquilezles.org/www/articles/spherefunctions/spherefunctions.htm
			bool SphereIntersect(float3 ro, float3 rd, float4 sph, out float nearHit, out float farHit)
			{
				float3 oc = ro - sph.xyz;
				float b = dot(oc, rd);
				float c = dot(oc, oc) - sph.w*sph.w;
				float h = b * b - c;
				if (h < 0.0f)
					return false;
				h = sqrt(h);
				nearHit = -b - h;
				farHit = -b + h;
				return true;
			}


			bool IsOutsideUnitCube(float3 pos)
			{
				return pos.x < 0.0f || pos.x > 1.0f || pos.y < 0.0f || pos.y > 1.0f || pos.z < 0.0f || pos.z > 1.0f;
			}

			void ComputeRay(v2f In, out float3 pos, out float3 dir, out float rayLength, out float3 outSurfaceNormal, out bool sphereHit)
			{
				// Generate camera ray and place in volume.
				float3 cameraPosVolume = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1.0f)).xyz;
				dir = normalize(In.volumePos - cameraPosVolume);
				pos = cameraPosVolume + cubeExtent;

				// Determine cut with box so we can shorten the ray.
				float2 boxIntersection = BoxIntersection(cameraPosVolume, dir, cubeExtent, outSurfaceNormal);
				rayLength = boxIntersection.y; // Maximal length to far box hit.

				// Check sphere before we shorten the start position.
				float brushSphereNearHit, brushSphereFarHit;
				sphereHit = SphereIntersect(pos, dir, _BrushPositionSize, brushSphereNearHit, brushSphereFarHit);
				sphereHit = sphereHit && brushSphereFarHit > boxIntersection.x;
				if (sphereHit)
				{
					if (brushSphereNearHit > boxIntersection.x)
						outSurfaceNormal = normalize(pos + dir * brushSphereNearHit - _BrushPositionSize.xyz);
					rayLength = min(brushSphereNearHit, rayLength);
				}

				// If outside, shorten ray to start at the cube.
				if (IsOutsideUnitCube(pos))
				{
					pos += dir * boxIntersection.x;
					rayLength -= boxIntersection.x;
				}
			}
			
			void ComputeShadowRay(float3 pos, float3 dir, out float rayLength, out bool sphereHit)
			{
				float3 outSurfaceNormal;
				float2 boxIntersection = BoxIntersection(pos - cubeExtent, dir, cubeExtent, outSurfaceNormal);
				rayLength = boxIntersection.y; // Maximal length to far box hit.

				float brushSphereNearHit, brushSphereFarHit;
				sphereHit = SphereIntersect(pos, dir, _BrushPositionSize, brushSphereNearHit, brushSphereFarHit);
				sphereHit = sphereHit && brushSphereNearHit > 0.0f && brushSphereFarHit > boxIntersection.x;
				if (sphereHit)
					rayLength = min(brushSphereNearHit, rayLength);
			}

			float EvaluateHenyeyGreensteinPhaseFunction(float g, float3 toLightNorm, float3 evalDirNorm)
			{
				const float gSq = g * g;
				return (1.0f - gSq) * pow(1.0f + gSq - 2.0f * g * dot(toLightNorm, evalDirNorm), -3.0f / 2.0f) * 0.25; // dropped 1/pi factor
			}

			float TraceShadowRay(float3 samplePos, float2 noisePos, int sampleIndex)
			{
				float3 dir = _WorldSpaceLightPos0.xyz;

				float shadowRayLength;
				bool shadowRaySphereHit;
				ComputeShadowRay(samplePos, dir, shadowRayLength, shadowRaySphereHit);
				if (shadowRaySphereHit)
					return _ScatterAmbient;

				float transmittance = 1.0f;
				const int maxNumSteps = min(maxNumRayMarchSteps_Shadow, (int)(shadowRayLength / _VolumeMarchStepSize_ShadowRay));
				float3 step = dir * _VolumeMarchStepSize_ShadowRay;

                float noise01 = tex3Dlod(_NoiseTexture, float4(noisePos, sampleIndex * _NoiseTexture_TexelSize.x, 0.0f)).a;
				samplePos += step * noise01;

				for (int i = 0; i < maxNumSteps && transmittance > 0.01; ++i)
				{
					samplePos += step;
					float density = SampleVolumeDensity(samplePos);
					float extinctionCoefficient = density * _ExtinctionFactor;
					float sampleTransmittance = exp(-extinctionCoefficient * _VolumeMarchStepSize);
					transmittance *= sampleTransmittance;
				}

				return max(_ScatterAmbient, transmittance);
			}

			float4 frag(v2f In) : COLOR
			{
				float3 cameraRayStartPos, dir;
				float maxRayLength;
				float3 surfaceNormal;
				bool sphereHit;
				ComputeRay(In, cameraRayStartPos, dir, maxRayLength, surfaceNormal, sphereHit);

				// Jitter sampling pos!
				float2 noisePos = In.vertex.xy * _NoiseTexture_TexelSize.x;
				float noise01 = tex3Dlod(_NoiseTexture, float4(In.vertex.xy * _NoiseTexture_TexelSize.x, 0.0f, 0.0f)).a;
				float randomOffset = noise01 * _VolumeMarchStepSize - _VolumeMarchStepSize * 0.5f;
				float3 samplePos = cameraRayStartPos + dir * randomOffset;
				const int maxNumSteps = min(maxNumRayMarchSteps, (int)((maxRayLength - randomOffset) / _VolumeMarchStepSize));
				// Since light direction is constant, we need to evaluate the scatter function only once.
				float hgPhase = EvaluateHenyeyGreensteinPhaseFunction(_ScatteringAnisotropy, _WorldSpaceLightPos0.xyz, -dir);
				float4 accumScatteringTransmittance = float4(0.0f, 0.0f, 0.0f, 1.0f);

				float3 step = dir * _VolumeMarchStepSize;
				for (int i = 0; i < maxNumSteps && accumScatteringTransmittance.a > 0.01; ++i)
				{
					samplePos += step;
					float density = SampleVolumeDensity(samplePos);

					float incomingRadiance = TraceShadowRay(samplePos, noisePos, i);
					float sampleScattering = incomingRadiance *_ScatteringFactor * density * _VolumeMarchStepSize * hgPhase;

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

				if (sphereHit)
				{
					float sphereLighting = dot(surfaceNormal, _WorldSpaceLightPos0.xyz);
					sphereLighting *= TraceShadowRay(cameraRayStartPos + dir * maxRayLength, noisePos, i);
					sphereLighting = saturate(sphereLighting) + _ScatterAmbient;
					return float4(sphereLighting.xxx * accumScatteringTransmittance.a + accumScatteringTransmittance.xyz, 0.0f);
				}
				else
					return accumScatteringTransmittance;
			}
			ENDCG
		}
	}
}
