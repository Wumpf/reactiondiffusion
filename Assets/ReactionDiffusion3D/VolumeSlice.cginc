float _VolumeDepth;

struct v2f_volumeSlice
{
	float4 position : SV_POSITION;
	float3 texcoord : TEXCOORD;
};

v2f_volumeSlice vert_volumeSlice(uint vertexId : SV_VertexID)
{
	v2f_volumeSlice v;
	v.texcoord = float3(float2((vertexId & 1) * 2.0f, vertexId & 2), _VolumeDepth);
	v.position = float4(v.texcoord.xy * 2.0f - 1.0f, 0.0f, 1.0f);
	v.texcoord.y = 1.0f - v.texcoord.y;
	return v;
}