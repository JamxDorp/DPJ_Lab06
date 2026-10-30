using TMPro;
using UnityEngine;

public class UIManager : MonoBehaviour
{
    public static UIManager Instance {get; private set;}

    [SerializeField] public TextMeshProUGUI scoreText;
    [SerializeField] public TextMeshProUGUI livesText;
    public int startLives = 3;
    public int score = 0;
    public int lives;

    private void Awake()
    {
        if (Instance != null && Instance != this) 
        { 
            Destroy(this); 
        } 
        else 
        { 
            Instance = this; 
        }

        lives = startLives;
        UpdateScoreUI();
        UpdateLivesUI();
    }

    private void UpdateScoreUI()
    {
        livesText.text = "Lives: " + lives;
    }

    private void UpdateLivesUI()
    {
        scoreText.text = "Score: " + score;
    }

    private void AddScore(int points)
    {
        score += points;
        UpdateScoreUI();
    }

    private void SetLives(int newLives)
    {
        lives = newLives;
        UpdateLivesUI();
    }
}
