using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class OIT : MonoBehaviour
{
    Material material;

    [System.Serializable]
    struct color4
    {
        public float r;
        public float g;
        public float b;
        public float a;
    }

    [System.Serializable]
    struct FragmentAndLinkBuffer_STRUCT
    {
        public color4 pixelColor;
        public float depth;
        public uint next;
    };

    int bufferSize;
    Resolution lastRes = new Resolution();

    ComputeBuffer rwStructuredBuffer;
    ComputeBuffer rwByteAddressBuffer;

    Camera depthCamera;

    void Awake()
    {
        GameObject depthCameraObj = new GameObject("DepthCamera");
        depthCameraObj.transform.SetParent(transform, false);
        depthCamera = depthCameraObj.AddComponent<Camera>();
        depthCamera.CopyFrom(Camera.main);
        depthCamera.clearFlags = CameraClearFlags.Color;
        depthCamera.backgroundColor = new Color(0, 0, 0, 0);
        depthCamera.SetReplacementShader(Shader.Find("Hidden/OIT_Depth"), "RenderType");

        material = new Material(Shader.Find("Hidden/OIT_Rendering"));

        lastRes.width = Screen.width;
        lastRes.height = Screen.height;
    }

    void resolutionChange()
    {
        // Debug.LogFormat("{0}x{1}", Screen.width, Screen.height);
        if (depthCamera.targetTexture != null)
        {
            depthCamera.targetTexture.Release();
            depthCamera.targetTexture = null;
            depthCamera.enabled = false;
        }
        RenderTexture depthTexture = new RenderTexture(Screen.width, Screen.height, 0, UnityEngine.Experimental.Rendering.GraphicsFormat.R8G8B8A8_UNorm);
        depthCamera.targetTexture = depthTexture;
        depthCamera.enabled = true;
        Shader.SetGlobalTexture("_OIT_Depth", depthTexture);

        bufferSize = Screen.width * Screen.height;

        if (rwStructuredBuffer != null)
            rwStructuredBuffer.Release();
        if (rwByteAddressBuffer != null)
            rwByteAddressBuffer.Release();
        Graphics.ClearRandomWriteTargets();
        rwStructuredBuffer = new ComputeBuffer(bufferSize * 2, sizeof(float) * 5 + sizeof(uint), ComputeBufferType.Counter);
        rwByteAddressBuffer = new ComputeBuffer(bufferSize, sizeof(uint), ComputeBufferType.Raw);
        Graphics.SetRandomWriteTarget(1, rwStructuredBuffer, false);
        Graphics.SetRandomWriteTarget(2, rwByteAddressBuffer);
    }

    void OnEnable()
    {
        resolutionChange();
        Shader.DisableKeyword("OIT_Editor");
        Shader.EnableKeyword("OIT_Runtime");
        Shader.DisableKeyword("OIT_OFF");
    }

    void disableOIT()
    {
        if (depthCamera.targetTexture != null)
        {
            depthCamera.targetTexture.Release();
            depthCamera.targetTexture = null;
            depthCamera.enabled = false;
        }
        if (rwStructuredBuffer != null)
            rwStructuredBuffer.Release();
        if (rwByteAddressBuffer != null)
            rwByteAddressBuffer.Release();
        Graphics.ClearRandomWriteTargets();
    }

    void OnDisable()
    {
        disableOIT();
        Shader.DisableKeyword("OIT_Editor");
        Shader.DisableKeyword("OIT_Runtime");
        Shader.EnableKeyword("OIT_OFF");
    }

    void OnDestroy()
    {
        disableOIT();
        Shader.EnableKeyword("OIT_Editor");
        Shader.DisableKeyword("OIT_Runtime");
        Shader.DisableKeyword("OIT_OFF");
    }

    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (lastRes.width != Screen.width ||
        lastRes.height != Screen.height)
        {
            lastRes.width = Screen.width;
            lastRes.height = Screen.height;
            resolutionChange();
        }

        Graphics.Blit(source, destination, material);

        rwStructuredBuffer.SetCounterValue(0);
    }
}
