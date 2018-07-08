Shader "ReactionDiffusion3D/Iteration"
{
	Properties
	{
		_MainTex ("Texture", 3D) = "white" {}
		_DiffusionRate ("DiffusionRate", float) = (1.0, 0.5, 0.0, 0.0)
		_KillRate ("KillRate", Float) = 0.062
		_FeedRate ("FeedRate", Float) = 0.0545
		_Speed ("Speed", Float) = 10.0
	}
	SubShader
	{
		Lighting Off

		Pass
		{
			CGPROGRAM
			#include "UnityCG.cginc"
			#include "VolumeSlice.cginc"
			#pragma vertex vert_volumeSlice
			#pragma fragment frag
			
			sampler3D _MainTex;
			float4 _MainTex_TexelSize;
			float2 _DiffusionRate;
			float _KillRate;
			float _FeedRate;
			float _Speed;

			float4 frag(v2f_volumeSlice In) : COLOR
			{
				return tex3D(_MainTex, In.texcoord);
			}
			ENDCG
		}
	}
}
