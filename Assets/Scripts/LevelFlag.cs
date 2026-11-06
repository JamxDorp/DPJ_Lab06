using UnityEngine;

[RequireComponent(typeof(Collider))]
public class LevelFlag : MonoBehaviour
{
    private void Awake()
    {
        Collider collider = GetComponent<Collider>();
        collider.isTrigger = true;
    }

    private void OnTriggerEnter(Collider other)
    {
        if (other.CompareTag("Player"))
        {
            int score = UIManager.Instance != null ? UIManager.Instance.score : 0;
            Debug.Log("Level complete - Total score: " + score);
        }
    }
}