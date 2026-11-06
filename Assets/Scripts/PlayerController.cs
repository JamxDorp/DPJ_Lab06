using UnityEngine;

public class PlayerController : MonoBehaviour
{
    [SerializeField] public float moveSpeed = 5f;
    [SerializeField] public float maxSpeed = 10f;
    [SerializeField] public float jumpForce = 10f;
    [SerializeField] public float groundCheckRadius = 0.1f;
    [SerializeField] public Transform groundCheck;
    [SerializeField] public LayerMask groundLayer;
    public float horizontalInput;
    private bool isGrounded;
    private Rigidbody rb;

    private void Awake()
    {
        rb = GetComponent<Rigidbody>();
        rb.freezeRotation = true;
    }

    private void Update()
    {
        horizontalInput = Input.GetAxis("Horizontal");
        isGrounded = IsGrounded();

        if (Input.GetButtonDown("Jump") && isGrounded)
        {
            Jump();
        }
    }

    private void FixedUpdate()
    {
        isGrounded = IsGrounded();
        Vector3 velocity = rb.linearVelocity;
        float targetVelX = horizontalInput * moveSpeed;
        float newVelX = Mathf.MoveTowards(velocity.x, targetVelX, 50f * Time.fixedDeltaTime);
        rb.linearVelocity = new Vector3(Mathf.Clamp(newVelX, -maxSpeed, maxSpeed), velocity.y, 0f);
    }

    private bool IsGrounded()
    {
        Collider[] hits = Physics.OverlapSphere(groundCheck.position, groundCheckRadius, groundLayer);
        foreach (Collider hit in hits)
        {
            if (hit.gameObject != gameObject && hit.transform.root != transform.root)
            {
                return true;
            }
        }
        return false;
    }

    private void Jump()
    {
        Debug.Log("Jumping");
        Vector3 velocity = rb.linearVelocity;
        velocity.y = 0;
        rb.linearVelocity = velocity;
        rb.AddForce(Vector3.up * jumpForce, ForceMode.Impulse);
    }
}
