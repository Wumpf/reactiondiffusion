using UnityEngine;
using UnityEngine.UI;

[RequireComponent(typeof(Toggle))]
public class ToggleButtonKeyBinding : MonoBehaviour
{
    public KeyCode KeyCode;

    void Update ()
    {
        if (Input.GetKeyDown(KeyCode))
            GetComponent<Toggle>().isOn = !GetComponent<Toggle>().isOn;
    }
}
