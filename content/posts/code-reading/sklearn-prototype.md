---
title: "Prototype은 실전에서 이렇게 쓰인다 — scikit-learn clone()"
date: 2026-05-23T16:06:00+09:00
draft: false
categories: ["Code Reading"]
tags: ["scikit-learn", "Prototype", "디자인패턴", "Python"]
---

> 이전 글 [Vibe Coding을 위한 디자인 패턴 - 프로토타입](/posts/design-pattern/designpattern-prototype/)을 읽었다는 가정 하에 쓴다.

## scikit-learn이 뭔지 3줄

scikit-learn은 Python으로 머신러닝 모델을 만들 때 쓰는 라이브러리다.  
`LogisticRegression()`, `RandomForestClassifier()` 같은 모델을 만들고 `.fit(X, y)`로 학습시킨다.  
GitHub 스타 61k, 실제 ML 프로젝트에서 가장 많이 쓰이는 라이브러리 중 하나다.

---

## 문제: "같은 설정의 모델을 여러 번 학습해야 한다"

GridSearchCV(하이퍼파라미터 탐색), 교차검증(cross-validation), 앙상블 모델에는 공통 문제가 있다.

```
GridSearchCV
  └─ LogisticRegression(C=0.1)을 5-fold 교차검증으로 평가
       ├─ fold 1: 모델 학습 → 평가 → 버림
       ├─ fold 2: 모델 학습 → 평가 → 버림
       ├─ fold 3: 모델 학습 → 평가 → 버림
       ├─ fold 4: 모델 학습 → 평가 → 버림
       └─ fold 5: 모델 학습 → 평가 → 버림
```

**fold마다 "아직 학습 안 된, 같은 설정의 새 모델"이 필요하다.**

그냥 같은 인스턴스를 재사용하면 안 된다. fold 1의 학습 결과가 fold 2에 섞인다.  
그렇다고 `LogisticRegression(C=0.1)`을 매번 직접 쓰면 GridSearchCV가 어떤 파라미터로 만들어야 하는지 코드 안에 하드코딩해야 한다.

scikit-learn은 이 문제를 `clone()`으로 해결한다.

---

## 해법: `clone()` — 파라미터만 복제하는 프로토타입

```python
# sklearn/base.py
from sklearn.base import clone
from sklearn.linear_model import LogisticRegression

fitted = LogisticRegression(C=0.1).fit(X, y)
fresh  = clone(fitted)

hasattr(fitted, "classes_")  # True  — 학습된 상태 있음
hasattr(fresh,  "classes_")  # False — 깨끗한 새 모델
fitted is fresh              # False — 별개의 객체
```

`clone()`은 학습된 결과(가중치, `classes_`, `coef_` 등)는 복사하지 않는다.  
**"어떻게 만들어졌는가"**(파라미터)만 복제하고, **"무엇을 배웠는가"**(상태)는 버린다.

프로토타입 패턴에서 "원본의 상태를 그대로 복제"하는 경우와 다르다. scikit-learn의 `clone()`은 **"설정 프로토타입"** 에 가깝다. 이 선택이 왜 맞는지는 아래에서 다시 본다.

---

## clone()이 실제로 하는 일

```python
# sklearn/base.py (단순화)
def clone(estimator, *, safe=True):
    # __sklearn_clone__ 프로토콜이 있으면 위임
    if hasattr(estimator, "__sklearn_clone__") and not inspect.isclass(estimator):
        return estimator.__sklearn_clone__()
    return _clone_parametrized(estimator, safe=safe)

def _clone_parametrized(estimator, *, safe=True):
    # list, tuple, dict 같은 컨테이너는 재귀적으로 복제
    estimator_type = type(estimator)
    if estimator_type in (list, tuple, set, frozenset):
        return estimator_type([clone(e, safe=safe) for e in estimator])
    if estimator_type is dict:
        return {k: clone(v, safe=safe) for k, v in estimator.items()}

    # get_params()가 없으면 sklearn estimator가 아님
    if not hasattr(estimator, "get_params"):
        if not safe:
            return copy.deepcopy(estimator)
        raise TypeError(...)

    klass = estimator.__class__

    # 1. 생성자 파라미터만 꺼냄 (학습된 상태는 제외)
    new_object_params = estimator.get_params(deep=False)

    # 2. 파라미터 값도 재귀적으로 clone
    for name, param in new_object_params.items():
        new_object_params[name] = clone(param, safe=False)

    # 3. 새 인스턴스 생성 — 학습 전 상태
    new_object = klass(**new_object_params)

    return new_object
```

세 단계로 요약된다.

1. `get_params(deep=False)` — `__init__`에 넘긴 파라미터만 가져온다
2. 각 파라미터 값을 재귀 `clone` — 중첩 estimator도 복제
3. `klass(**params)`로 새 인스턴스 생성

`copy.deepcopy(estimator)` 한 줄이 아닌 이유는 학습된 상태를 **의도적으로 빼기 위해서다.**

---

## get_params() — 무엇을 복제할지 알려주는 인터페이스

`clone()`이 동작하려면 estimator가 `get_params()`를 구현해야 한다.

```python
# sklearn/base.py — BaseEstimator.get_params()
def get_params(self, deep=True):
    out = dict()
    for key in self._get_param_names():  # __init__ 파라미터 이름 목록
        value = getattr(self, key)
        if deep and hasattr(value, "get_params"):
            # 중첩 estimator면 그것의 파라미터도 포함
            deep_items = value.get_params().items()
            out.update((key + "__" + k, val) for k, val in deep_items)
        out[key] = value
    return out

def _get_param_names(cls):
    # inspect로 __init__ 시그니처를 읽는다
    init = cls.__init__
    init_signature = inspect.signature(init)
    parameters = [p for p in init_signature.parameters.values()
                  if p.name != "self" and p.kind != p.VAR_KEYWORD]
    return sorted([p.name for p in parameters])
```

`inspect.signature`로 `__init__`의 파라미터 이름을 꺼내고, 그 이름으로 `self.속성`을 읽는다.

즉 scikit-learn의 규칙은 이것이다.

> `__init__`에서 받은 파라미터는 반드시 `self.파라미터명 = 파라미터`로 저장해야 한다.

```python
class MyEstimator(BaseEstimator):
    def __init__(self, alpha=1.0, max_iter=100):
        self.alpha = alpha        # 규칙 준수 ✅
        self.max_iter = max_iter  # 규칙 준수 ✅
        # self.alpha_ = None     # 학습 결과는 _로 끝나는 이름 사용 (관례)
```

이 규칙을 지키면 `get_params()`가 자동으로 동작하고, `clone()`도 자동으로 동작한다.

---

## Pipeline 안의 clone — 중첩 복제

Pipeline은 여러 단계(전처리 → 모델)를 묶는다. clone은 이를 재귀적으로 복제한다.

```python
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.linear_model import LogisticRegression

pipe = Pipeline([
    ("scaler", StandardScaler()),
    ("clf", LogisticRegression(C=0.1))
])

cloned = clone(pipe)
```

내부에서 일어나는 일:

```
clone(pipe)
  └─ pipe.get_params(deep=False)
       → {"steps": [("scaler", StandardScaler()), ("clf", LogisticRegression(C=0.1))]}
  └─ clone(steps 리스트) — 리스트니까 원소 각각 재귀
       ├─ clone(("scaler", StandardScaler()))
       └─ clone(("clf", LogisticRegression(C=0.1)))
            └─ LogisticRegression.get_params(deep=False)
                 → {"C": 0.1, "solver": "lbfgs", ...}
            └─ LogisticRegression(C=0.1, solver="lbfgs", ...)
```

Pipeline 전체가 복제되고, 각 단계도 학습 전 상태로 초기화된다.

---

## __sklearn_clone__ — 확장 포인트

v1.3부터 클래스에 `__sklearn_clone__`이 있으면 `clone()`이 이를 먼저 호출한다.

```python
# sklearn/base.py
def clone(estimator, *, safe=True):
    if hasattr(estimator, "__sklearn_clone__") and not inspect.isclass(estimator):
        return estimator.__sklearn_clone__()  # 커스텀 복제 로직에 위임
    return _clone_parametrized(estimator, safe=safe)
```

기본 `_clone_parametrized`로는 복제가 어려운 객체가 있다.

- `random_state`가 `np.random.RandomState` 인스턴스인 경우
- 외부 라이브러리 wrapping estimator (XGBoost, LightGBM 등)
- 복제 시 특별한 초기화가 필요한 경우

이런 경우 `__sklearn_clone__`을 직접 구현해서 복제 방식을 제어할 수 있다.

```python
class MySpecialEstimator(BaseEstimator):
    def __init__(self, model_path, config):
        self.model_path = model_path
        self.config = config

    def __sklearn_clone__(self):
        # 파일에서 설정만 다시 읽어서 새 인스턴스 생성
        return MySpecialEstimator(
            model_path=self.model_path,
            config=copy.deepcopy(self.config)
        )
```

프로토타입 포스트의 `clone()` 메서드를 오버라이드하는 것과 같은 구조다.

---

## 왜 deepcopy를 안 쓰나

가장 직관적인 구현은 `copy.deepcopy(estimator)`다. 왜 이렇게 하지 않을까?

1. **학습된 상태까지 복사된다** — numpy 배열인 `coef_`, `feature_importances_` 등이 통째로 복사된다. GridSearchCV에서 수십 번 호출되면 메모리 낭비가 크다.

2. **외부 리소스가 복제된다** — DB 커넥션, 파일 핸들 같은 것이 있으면 `deepcopy`가 실패하거나 의도치 않게 복제된다.

3. **"아직 학습 안 된 상태"가 보장되지 않는다** — GridSearchCV 입장에서 clone 결과가 반드시 미학습 상태임을 보장받아야 한다.

```python
# clone() — 파라미터만 복제, 빠르고 예측 가능
fresh = clone(estimator)       # 항상 미학습 상태 보장

# deepcopy — 전부 복제, 느리고 학습 상태 포함
copy_of = copy.deepcopy(estimator)  # 학습 상태까지 그대로
```

**"무엇을 복제할지 명시적으로 정의한다"**는 것이 프로토타입 패턴의 핵심이다. scikit-learn은 `get_params()` 인터페이스로 "복제 대상"을 명시적으로 정의하고, deepcopy의 "전부 복사"를 쓰지 않는다.

---

## 실제로 clone이 쓰이는 곳

```python
# cross_validate — fold마다 clone
def cross_validate(estimator, X, y, ...):
    for train, test in cv.split(X, y):
        clone_estimator = clone(estimator)  # 매 fold마다 새 모델
        clone_estimator.fit(X[train], y[train])
        scores.append(clone_estimator.score(X[test], y[test]))

# GridSearchCV — 파라미터 조합마다 clone
def fit(self, X, y):
    for params in param_grid:
        cloned = clone(self.estimator)
        cloned.set_params(**params)
        cloned.fit(X_train, y_train)

# Pipeline — 각 step을 clone
def fit(self, X, y):
    cloned_steps = [(name, clone(est)) for name, est in self.steps]
    for name, est in cloned_steps:
        X = est.fit_transform(X)
```

모두 같은 패턴이다. **원본을 건드리지 않고, 설정이 같은 새 인스턴스가 필요할 때** clone을 쓴다.

---

## Prototype 패턴의 교훈 — "무엇을 복제할지 설계가 필요하다"

프로토타입 포스트에서 가장 중요한 부분은 이거였다.

> 얕은 복사와 깊은 복사를 의도적으로 나눠야 한다.

scikit-learn의 clone이 보여주는 것은 그 이상이다.

> deepcopy와 "선택적 복제" 사이에서 **"무엇을 복제에 포함시킬 것인가"를 명시적으로 설계해야 한다.**

| | `clone()` | `copy.deepcopy()` |
|---|---|---|
| 복제 대상 | `get_params()` 반환값만 | 모든 속성 |
| 학습된 상태 | 제외 | 포함 |
| 속도 | 빠름 | 느림 |
| 결과 보장 | 항상 미학습 | 학습 상태 그대로 |
| 확장 | `__sklearn_clone__` | `__deepcopy__` |

scikit-learn은 "복제에 포함할 것"(`get_params`)과 "복제에서 제외할 것"(학습된 상태)을 `_`로 끝나는 속성 이름 관례로 나눈다.

```
self.C = 1.0        # __init__ 파라미터 → clone에 포함
self.coef_ = None   # 학습 결과 → clone에 미포함 (언더스코어로 끝남)
```

이 규칙 하나로 `get_params()`와 `clone()`이 자동으로 올바르게 동작한다.

---

## 한 줄 정리

> scikit-learn의 `clone()`은 "객체를 통째로 복사"하는 대신, `get_params()` 인터페이스로 **"복제에 포함할 것"을 명시적으로 정의**하고 그것만 복제한다. 프로토타입 패턴에서 `clone()` 메서드 안에서 어떤 필드를 복사할지 직접 제어해야 하는 이유가 실제 코드에서 정확히 드러난다.
