using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class EnableImageEffect : MonoBehaviour
{
    // Start is called before the first frame update
    void OnEnable()
    {
        GetComponent<UnityStandardAssets.CinematicEffects.Bloom>().enabled = true;
        GetComponent<UnityStandardAssets.CinematicEffects.TonemappingColorGrading>().enabled = true;
        GetComponent<UnityStandardAssets.CinematicEffects.AntiAliasing>().enabled = true;
    }
    void OnDisable()
    {
        GetComponent<UnityStandardAssets.CinematicEffects.Bloom>().enabled = false;
        GetComponent<UnityStandardAssets.CinematicEffects.TonemappingColorGrading>().enabled = false;
        GetComponent<UnityStandardAssets.CinematicEffects.AntiAliasing>().enabled = false;
    }
}
