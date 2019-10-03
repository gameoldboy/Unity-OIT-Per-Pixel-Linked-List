using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class FPSCounter : MonoBehaviour
{
    int ticks = 0;
    float time;
    Text fps;

    void Start()
    {
        QualitySettings.vSyncCount = 0;
        fps = GetComponent<Text>();
        time = Time.realtimeSinceStartup;
    }
    void Update()
    {
        ticks++;
        if (Time.realtimeSinceStartup - time > 1)
        {
            time = Time.realtimeSinceStartup;
            fps.text = ticks.ToString();
            ticks = 0;
        }
    }
}
