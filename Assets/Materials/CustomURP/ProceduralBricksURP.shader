Shader "Custom/URP/Procedural Bricks"
{
    Properties
    {
        [Header(Bricks)]
        _BrickColorA("Cor do tijolo A", Color) = (0.62, 0.24, 0.17, 1)
        _BrickColorB("Cor do tijolo B", Color) = (0.45, 0.17, 0.12, 1)
        _ColorVariation("Variação por tijolo", Range(0, 1)) = 0.25
        _Smoothness("Smoothness (tijolo)", Range(0, 1)) = 0.15

        [Header(Mortar)]
        _MortarColor("Cor da argamassa", Color) = (0.62, 0.60, 0.55, 1)
        _MortarWidth("Largura da junta (UV)", Range(0.002, 0.05)) = 0.012
        _MortarSmoothness("Smoothness (argamassa)", Range(0, 1)) = 0.05

        [Header(Layout)]
        _Tiling("Tiling", Vector) = (1, 1, 0, 0)
        _Columns("Tijolos por linha", Float) = 6
        _Rows("Número de fiadas", Float) = 12
        _RowOffset("Desfasamento das fiadas", Range(0, 1)) = 0.5

        [Header(Relief and Noise)]
        _Bevel("Chanfro", Range(0.01, 0.5)) = 0.1
        _BumpStrength("Intensidade do relevo", Range(0, 0.3)) = 0.05
        _NoiseScale("Escala do ruído", Float) = 12
        _NoiseAmount("Rugosidade do tijolo", Range(0, 1)) = 0.25
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "Queue" = "Geometry" }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
            float4 _BrickColorA;
            float4 _BrickColorB;
            float4 _MortarColor;
            float4 _Tiling;
            float _ColorVariation;
            float _Smoothness;
            float _MortarWidth;
            float _MortarSmoothness;
            float _Columns;
            float _Rows;
            float _RowOffset;
            float _Bevel;
            float _BumpStrength;
            float _NoiseScale;
            float _NoiseAmount;
        CBUFFER_END

        float Hash21(float2 p)
        {
            p = frac(p * float2(123.34, 456.21));
            p += dot(p, p + 45.32);
            return frac(p.x * p.y);
        }

        float ValueNoise(float2 p)
        {
            float2 i = floor(p);
            float2 f = frac(p);
            f = f * f * (3.0 - 2.0 * f);
            float a = Hash21(i);
            float b = Hash21(i + float2(1, 0));
            float c = Hash21(i + float2(0, 1));
            float d = Hash21(i + float2(1, 1));
            return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
        }

        struct BrickData
        {
            float height; // 0 na junta, 1 no topo do tijolo
            float mask;   // 0 junta, 1 tijolo
            float2 id;    // id único do tijolo
        };

        BrickData Brick(float2 uv)
        {
            float2 g = uv * _Tiling.xy * float2(_Columns, _Rows);
            float row = floor(g.y);
            g.x += abs(fmod(row, 2.0)) * _RowOffset;

            float2 id = floor(g);
            float2 f = frac(g);

            float2 mortarHalf = _MortarWidth * float2(_Columns, _Rows) * 0.5;
            float2 e = min(f, 1.0 - f) - mortarHalf;
            float d = min(e.x, e.y);

            BrickData o;
            o.height = saturate(d / max(_Bevel, 1e-4));
            o.mask = smoothstep(0.0, 0.03, d);
            o.id = id;
            return o;
        }

        float HeightAt(float2 uv)
        {
            BrickData b = Brick(uv);
            float n = ValueNoise(uv * _Tiling.xy * _NoiseScale);
            return b.height + (n - 0.5) * _NoiseAmount * 0.5;
        }
        ENDHLSL

        // ------------------------------------------------------------
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile _ _FORWARD_PLUS _CLUSTER_LIGHT_LOOP
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float4 tangentOS  : TANGENT;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS   : TEXCOORD2;
                float3 tangentWS  : TEXCOORD3;
                float3 bitangentWS: TEXCOORD4;
                float4 fogAndVL   : TEXCOORD5; // x = fog, yzw = vertex lighting
            };

            Varyings vert(Attributes v)
            {
                Varyings o;
                VertexPositionInputs pos = GetVertexPositionInputs(v.positionOS.xyz);
                VertexNormalInputs nrm = GetVertexNormalInputs(v.normalOS, v.tangentOS);

                o.positionCS = pos.positionCS;
                o.positionWS = pos.positionWS;
                o.uv = v.uv;
                o.normalWS = nrm.normalWS;
                o.tangentWS = nrm.tangentWS;
                o.bitangentWS = nrm.bitangentWS;

                float3 vl = 0;
                #ifdef _ADDITIONAL_LIGHTS_VERTEX
                    vl = VertexLighting(pos.positionWS, nrm.normalWS);
                #endif
                o.fogAndVL = float4(ComputeFogFactor(pos.positionCS.z), vl);
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                // --- Padrão de tijolos ---
                BrickData b = Brick(i.uv);
                float rnd  = Hash21(b.id);
                float rnd2 = Hash21(b.id + 7.31);
                float grain = ValueNoise(i.uv * _Tiling.xy * _NoiseScale * 2.0);

                float3 brickCol = lerp(_BrickColorA.rgb, _BrickColorB.rgb, rnd);
                brickCol *= 1.0 + (rnd2 - 0.5) * _ColorVariation;
                brickCol *= lerp(0.85, 1.1, grain);

                float3 mortarCol = _MortarColor.rgb * lerp(0.88, 1.1, ValueNoise(i.uv * _Tiling.xy * _NoiseScale * 3.0));

                float3 albedo = lerp(mortarCol, brickCol, b.mask);
                float smoothness = lerp(_MortarSmoothness, _Smoothness, b.mask);
                float occlusion = lerp(0.55, 1.0, smoothstep(0.0, 0.5, b.height));

                // --- Normal map procedural (a partir do mapa de alturas) ---
                const float eps = 0.0008;
                float h0 = HeightAt(i.uv);
                float hx = HeightAt(i.uv + float2(eps, 0));
                float hy = HeightAt(i.uv + float2(0, eps));
                float2 cellScale = _Tiling.xy * float2(_Columns, _Rows);
                float sx = (hx - h0) / (eps * cellScale.x);
                float sy = (hy - h0) / (eps * cellScale.y);
                float3 normalTS = normalize(float3(-sx * _BumpStrength, -sy * _BumpStrength, 1.0));

                float3x3 tbn = float3x3(normalize(i.tangentWS), normalize(i.bitangentWS), normalize(i.normalWS));
                float3 normalWS = NormalizeNormalPerPixel(TransformTangentToWorld(normalTS, tbn));

                // --- Dados para o PBR do URP ---
                InputData inputData = (InputData)0;
                inputData.positionWS = i.positionWS;
                inputData.positionCS = i.positionCS;
                inputData.normalWS = normalWS;
                inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(i.positionWS);
                inputData.shadowCoord = TransformWorldToShadowCoord(i.positionWS);
                inputData.fogCoord = i.fogAndVL.x;
                inputData.vertexLighting = i.fogAndVL.yzw;
                inputData.bakedGI = SampleSH(normalWS);
                inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(i.positionCS);
                inputData.shadowMask = half4(1, 1, 1, 1);

                SurfaceData s = (SurfaceData)0;
                s.albedo = albedo;
                s.metallic = 0;
                s.specular = 0;
                s.smoothness = smoothness;
                s.occlusion = occlusion;
                s.normalTS = normalTS;
                s.emission = 0;
                s.alpha = 1;

                half4 color = UniversalFragmentPBR(inputData, s);
                color.rgb = MixFog(color.rgb, inputData.fogCoord);
                return half4(color.rgb, 1);
            }
            ENDHLSL
        }

        // ------------------------------------------------------------
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            float3 _LightDirection;
            float3 _LightPosition;

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };

            Varyings vert(Attributes v)
            {
                Varyings o;
                float3 positionWS = TransformObjectToWorld(v.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(v.normalOS);

                #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                    float3 lightDirectionWS = normalize(_LightPosition - positionWS);
                #else
                    float3 lightDirectionWS = _LightDirection;
                #endif

                float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));
                #if UNITY_REVERSED_Z
                    positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE * positionCS.w);
                #else
                    positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE * positionCS.w);
                #endif
                o.positionCS = positionCS;
                return o;
            }

            half4 frag(Varyings i) : SV_Target { return 0; }
            ENDHLSL
        }

        // ------------------------------------------------------------
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ColorMask R

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex vert
            #pragma fragment frag

            struct Attributes { float4 positionOS : POSITION; };
            struct Varyings   { float4 positionCS : SV_POSITION; };

            Varyings vert(Attributes v)
            {
                Varyings o;
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                return o;
            }

            half frag(Varyings i) : SV_Target { return i.positionCS.z; }
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
