using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class EnableShadow : MonoBehaviour
{
    void OnEnable()
    {
        GetComponent<Light>().shadows = LightShadows.Soft;
    }
    void OnDisable()
    {
        GetComponent<Light>().shadows = LightShadows.None;
    }
}
