using UnityEngine;

public class CameraControls : MonoBehaviour
{
    public float MoveSpeed = 0.5f;
    public float MoveSpeedModifierFactor = 10.0f;
    public float RotateSpeed = 0.3f;
    public float ConfinmentZone = 4.5f;
    
    private Vector3 lastMousePosition;
    private float rotationX, rotationY;

    private void Start()
    {
        rotationX = transform.eulerAngles.x;
        if (rotationX > 90.0f) rotationX -= 360.0f;
        rotationY = transform.eulerAngles.y;
    }

    void Update ()
	{
        float moveSpeed = MoveSpeed;
	    if (Input.GetKey(KeyCode.LeftShift))
	        moveSpeed *= MoveSpeedModifierFactor;

        if (Input.GetKey(KeyCode.W))
            transform.position += transform.forward * moveSpeed * Time.deltaTime;
        if (Input.GetKey(KeyCode.S))
            transform.position -= transform.forward * moveSpeed * Time.deltaTime;
        if (Input.GetKey(KeyCode.D))
            transform.position += transform.right * moveSpeed * Time.deltaTime;
        if (Input.GetKey(KeyCode.A))
            transform.position -= transform.right * moveSpeed * Time.deltaTime;
	    //transform.position =
	    //    new Vector3()
	    //    {
	    //        x = Mathf.Clamp(transform.position.x, -ConfinmentZone, ConfinmentZone),
	    //        y = Mathf.Clamp(transform.position.y, -ConfinmentZone, ConfinmentZone),
	    //        z = Mathf.Clamp(transform.position.z, -ConfinmentZone, ConfinmentZone),
	    //    };

        if (Input.GetMouseButton(1))
        {
            var deltaRot = (lastMousePosition - Input.mousePosition) * RotateSpeed;
            rotationX += deltaRot.y;
            rotationX = Mathf.Clamp(rotationX, -80.0f, 80.0f);
            rotationY -= deltaRot.x;
            transform.eulerAngles = new Vector3(rotationX, rotationY, 0.0f);
        }
	    lastMousePosition = Input.mousePosition;
	}
}
