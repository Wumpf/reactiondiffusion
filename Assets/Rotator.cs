using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Rotator : MonoBehaviour
{
    void Update ()
    {
	    transform.Rotate(0.0f, Time.deltaTime*10.0f, 0.0f);
    }
}
