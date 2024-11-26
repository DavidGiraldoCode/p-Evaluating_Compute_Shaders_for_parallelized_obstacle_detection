using System.Collections;
using UnityEditor.Experimental.GraphView;
using UnityEngine;

/// <summary>
/// Controls the AoE wind power by defining it redious and the duration of the attack.
/// Internally, it controlls the shader that drives the wind look
/// </summary>
public class AoEWindController : MonoBehaviour
{
    [Tooltip("The radious of the dome")]
    [Range(1, 5)]
    [SerializeField] private float _areaOfEffect = 0.25f;

    [Tooltip("The time in seconds the effect last")]
    [Range(1, 10)]
    [SerializeField] private float _effectDuration = 5;

    #region Shader parameters
    private Material _windMaterial;
    private float _visibility;
    [SerializeField] private float _visibilityDelta = 0.5f;
    private float _effectCounter;
    [Tooltip("Read only")]
    [SerializeField] private bool _effectInProgress;
    private bool _hasFadedIn = false;
    private bool _hasFadedOut = false;

    [Tooltip("Enable changes on the shader at run-time")]
    [SerializeField] private bool _update = false;

    #endregion

    private void Awake()
    {
        //_visibility = 1.0f;
        //_areaOfEffect = (transform.localScale * 0.25f).magnitude;
        _windMaterial = GetComponentInChildren<MeshRenderer>().material;
        UpdateShaderVariables();

        //TODO 
        //Activate();


    }
    private void Update()
    {
        Activate();
    }

    /// <summary>
    /// Updates fields on the shader
    /// </summary>
    private void UpdateShaderVariables()
    {
        _windMaterial.SetFloat("_Visibility", _visibility);
        _windMaterial.SetVector("_Center", transform.position);
        _windMaterial.SetFloat("_Radius", _areaOfEffect);
    }

    public void Activate()
    {
#if UNITY_EDITOR
        Debug.Log($"_effectInProgress: {_effectInProgress}");
#endif
        if (_effectInProgress) return;
        //_effectInProgress = true;
        StartCoroutine(InvokingAoEWindDome());
    }


    /// <summary>
    /// Triggers the AoE wind power. It will last until the counter reaches the effect Duration
    /// </summary>
    private IEnumerator InvokingAoEWindDome()
    {
        FadeInVisibility();
        _effectCounter = 0.0f;

        while (_effectCounter < _effectDuration)
        {
            _effectCounter += Time.deltaTime;
            // Once the effect duration is over, fade out

            yield return null; // Continue until the effect duration has passed
        }

        if (FadeOutVisibility())
        {
            _effectInProgress = false; // Allow re-triggering of the effect after fade out
            _effectCounter = 0.0f;
            _hasFadedIn = false;
            _hasFadedOut = false;

#if UNITY_EDITOR
            Debug.Log($"_effectInProgress: {_effectInProgress}");
#endif
        }

        /*
        //_effectInProgress = true;
        FadeInVisibility();
        _effectCounter += 1.0f * Time.deltaTime;

        if (_effectCounter > _effectDuration)
            if (FadeOutVisibility())
            {
                _effectInProgress = false;
                _effectCounter = 0.0f;
                _hasFadedIn = false;
                _hasFadedOut = false;
#if UNITY_EDITOR
                Debug.Log($"_effectInProgress: {_effectInProgress}");
#endif
                StopAllCoroutines();
                yield return null;
            }


#if UNITY_EDITOR
        Debug.Log($"_visibility: {_visibility} _effectCounter: {_effectCounter}");
#endif
*/

    }

    private bool FadeInVisibility()
    {
        if (_hasFadedIn) return true;

        //_visibilityDelta += 0.5f * Time.deltaTime;
        //_visibility += _visibilityDelta * _visibilityDelta;
        _visibility += _visibilityDelta * _visibilityDelta * Time.deltaTime;
        if (_visibility >= 1)
        {
            _visibility = 1.0f;
            //_visibilityDelta = 0.0f;
            _hasFadedIn = true;
        }

        _windMaterial.SetFloat("_Visibility", _visibility);

        return false;

    }

    private bool FadeOutVisibility()
    {
        if (_hasFadedOut) return true;

        //_visibilityDelta += 0.5f * Time.deltaTime;
        //_visibility -= _visibilityDelta * _visibilityDelta;

        _visibility -= _visibilityDelta * _visibilityDelta * Time.deltaTime;
        if (_visibility <= 0)
        {
            _visibility = 0.0f;
            //_visibilityDelta = 0.0f;
            _hasFadedOut = true;
        }

        _windMaterial.SetFloat("_Visibility", _visibility);

        return false;
    }


}
