using UnityEngine;

[RequireComponent(typeof(Collider))]
public class Token : MonoBehaviour
{
    [SerializeField] public int Value = 10;
    [SerializeField] public AudioClip pickupSfx;

    private void Awake()
    {
        Collider collider = GetComponent<Collider>();
        collider.isTrigger = true;
    }

    private void OnTriggerEnter(Collider other)
    {
        if (!other.CompareTag("Player"))
        {
            return;
        }

        if (UIManager.Instance != null)
        {
            UIManager.Instance.AddScore(Value);
        }

        if (pickupSfx != null)
        {
            AudioSource.PlayClipAtPoint(pickupSfx, transform.position);
        }

        Destroy(gameObject);
    }
}