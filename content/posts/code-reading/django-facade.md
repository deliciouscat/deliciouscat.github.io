---
title: "Facade는 실전에서 이렇게 쓰인다 — Django shortcuts.py"
date: 2026-06-07T21:40:00+09:00
draft: false
categories: ["Code Reading"]
tags: ["Python", "Facade", "디자인패턴", "Django", "결합도"]
---

> 이전 글 [Vibe Coding을 위한 디자인 패턴 - 퍼사드](/posts/design-pattern/designpattern-facade/)를 읽었다는 가정 하에 쓴다.

## 들어가기 전에

퍼사드 패턴을 공부할 때 가장 헷갈리는 지점이 하나 있다.

> "Facade는 결합도를 낮추는 패턴"이라는데, 정작 Facade 자신은 여러 서브시스템에 결합되잖아?

맞다. 그리고 이게 핵심이다. **Facade는 결합을 없애는 패턴이 아니라, 결합이 생길 수밖에 없는 지점을 의식적으로 한 곳에 모으는 패턴이다.** 이 문장을 코드로 가장 노골적으로 증명하는 파일이 Django의 `django/shortcuts.py`다.

소스: [django/shortcuts.py](https://github.com/django/django/blob/main/django/shortcuts.py)

---

## 파일 첫 주석부터가 선언이다

`shortcuts.py`는 파일 맨 위 docstring에서 자신이 무슨 일을 하는 모듈인지 대놓고 말한다.

```python
"""
This module collects helper functions and classes that "span" multiple levels
of MVC. In other words, these functions/classes introduce controlled coupling
for convenience's sake.
"""
```

번역하면 이렇다.

> 이 모듈은 MVC의 여러 레벨을 **가로지르는(span)** helper 함수/클래스를 모은다. 다시 말해, 편의를 위해 **의도된 결합(controlled coupling)** 을 도입한다.

대부분의 잘 설계된 모듈은 "나는 한 가지 레벨의 책임만 진다"고 말한다. `shortcuts.py`는 정반대로, "나는 일부러 여러 레벨을 가로지른다"고 선언한다. 이게 바로 퍼사드의 정체성이다. 교과서에서 말하는 *디미터의 법칙(최소 지식 원칙)을 view가 지킬 수 있도록, 그 위반을 대신 떠안아 주는 계층*인 것이다.

`controlled`라는 단어가 중요하다. 결합 자체는 피할 수 없다. 다만 그 결합이 view 코드 곳곳에 흩어지게 둘 것이냐, 아니면 한 파일에 가둬서 관리할 것이냐의 차이다.

---

## 예시 1: `render()` — 템플릿 시스템과 응답 객체를 묶는다

가장 단순한 퍼사드 함수다.

```python
# django/shortcuts.py
from django.template import loader
from django.http import HttpResponse

def render(
    request, template_name, context=None, content_type=None, status=None, using=None
):
    """
    Return an HttpResponse whose content is filled with the result of calling
    django.template.loader.render_to_string() with the passed arguments.
    """
    content = loader.render_to_string(template_name, context, request, using=using)
    return HttpResponse(content, content_type, status)
```

이 한 줄짜리 본문 안에 두 개의 서로 다른 서브시스템이 묶여 있다.

- `django.template.loader` — 템플릿 엔진 (렌더링 계층)
- `django.http.HttpResponse` — HTTP 응답 객체 (전송 계층)

퍼사드가 없다면 모든 view가 이렇게 써야 한다.

```python
# Facade 없이 — view가 두 서브시스템을 직접 안다
def my_view(request):
    content = loader.render_to_string("index.html", {"x": 1}, request)
    return HttpResponse(content, content_type="text/html")
```

view 코드는 "템플릿을 문자열로 렌더한 뒤, 그 문자열을 응답 객체로 감싼다"는 **순서와 조립 방식**을 알아야 한다. `render()`는 이 지식을 가져가 버린다.

```python
# Facade 사용 — view는 "무엇을" 렌더할지만 안다
def my_view(request):
    return render(request, "index.html", {"x": 1})
```

결합이 사라진 게 아니다. **view → (template loader + HttpResponse)** 였던 결합이 **view → render → (template loader + HttpResponse)** 로 옮겨갔을 뿐이다. 두 서브시스템에 대한 결합은 이제 `shortcuts.py`가 떠안는다.

---

## 예시 2: `redirect()` — URL 해석의 복잡도를 삼킨다

`redirect()`는 더 흥미롭다. 호출자는 "어디로 보낼지"만 넘기면 되는데, 그 "어디"가 세 가지 형태일 수 있다.

```python
# django/shortcuts.py
def redirect(to, *args, permanent=False, ...):
    """
    The arguments could be:
    * A model: the model's `get_absolute_url()` function will be called.
    * A view name, possibly with arguments: `urls.reverse()` will be used.
    * A URL, which will be used as-is for the redirect location.
    """
    redirect_class = (
        HttpResponsePermanentRedirect if permanent else HttpResponseRedirect
    )
    return redirect_class(resolve_url(to, *args, **kwargs), ...)
```

`to`로 모델 인스턴스, view 이름 문자열, 생짜 URL 중 무엇이 들어와도 알아서 처리한다. 그 분기 로직은 같은 파일의 `resolve_url()`에 들어 있다.

```python
# django/shortcuts.py — resolve_url() (발췌)
def resolve_url(to, *args, **kwargs):
    # 1. 모델이면 get_absolute_url() 호출
    if hasattr(to, "get_absolute_url"):
        return to.get_absolute_url()
    # 2. 상대 URL이면 그대로
    if isinstance(to, str) and to.startswith(("./", "../")):
        return to
    # 3. view 이름이면 reverse()로 역해석
    try:
        return reverse(to, args=args, kwargs=kwargs)
    except NoReverseMatch:
        ...
    # 4. 그 외에는 URL로 간주
    return to
```

여기서 `redirect()`가 묶는 서브시스템은 세 개다.

- **ORM/모델 계층** — `get_absolute_url()`
- **URL dispatcher** — `reverse()` / `NoReverseMatch`
- **HTTP 계층** — `HttpResponseRedirect` / `HttpResponsePermanentRedirect`

호출자 입장에서는 `redirect(my_object)`나 `redirect("home")`이나 똑같이 한 줄이다. "URL을 어떻게 해석하는가"라는 복잡도 전체가 퍼사드 안으로 들어갔다.

---

## 예시 3: `get_object_or_404()` — 두 세계를 일부러 연결한다

결합도 이야기에 가장 맛있는 함수다.

```python
# django/shortcuts.py
from django.http import Http404

def get_object_or_404(klass, *args, **kwargs):
    queryset = _get_queryset(klass)
    if not hasattr(queryset, "get"):
        raise ValueError(...)  # 잘못된 타입 방어
    try:
        return queryset.get(*args, **kwargs)
    except queryset.model.DoesNotExist:
        raise Http404(
            _("No %s matches the given query.")
            % queryset.model._meta.object_name
        )
```

이 함수가 묶는 두 세계를 보자.

- `queryset.get()` 과 `DoesNotExist` — **ORM 계층**의 개념
- `Http404` — **웹/HTTP 계층**의 개념

여기서 핵심 통찰이 나온다. **이 두 세계는 원래 분리되어 있어야 정상이다.**

- 순수 ORM 계층에서 "객체가 없음"의 올바른 표현은 `DoesNotExist`다. ORM은 자기가 웹에서 쓰이는지 배치 스크립트에서 쓰이는지 알 필요가 없다.
- 웹 view 계층에서 "객체가 없음"의 올바른 표현은 `Http404`다. 404는 HTTP의 개념이지 데이터베이스의 개념이 아니다.

`get_object_or_404()`는 이 둘을 **일부러 연결한다.** `DoesNotExist`를 잡아서 `Http404`로 번역하는 것이다. 이건 깨끗한 계층 분리 관점에서 보면 "위반"이다. ORM 예외가 HTTP 예외로 변신하니까.

하지만 이 위반은 의도된 것이다. 만약 이 함수가 없다면 모든 view에 이 보일러플레이트가 반복된다.

```python
# Facade 없이 — 모든 view가 두 계층을 직접 잇는다
def article_view(request, pk):
    try:
        article = Article.objects.get(pk=pk)
    except Article.DoesNotExist:
        raise Http404("No Article matches the given query.")
    ...
```

`get_object_or_404()`는 이 "ORM 예외 → HTTP 예외" 번역 책임을 한 곳으로 모은다.

```python
# Facade 사용
def article_view(request, pk):
    article = get_object_or_404(Article, pk=pk)
    ...
```

**대가도 분명하다.** `get_object_or_404()`는 ORM과 HTTP 양쪽에 결합되어 있으므로, HTTP 맥락이 아닌 곳(예: 순수 데이터 처리 스크립트, Celery 태스크)에서는 쓰기 어색하다. 거기서는 `Http404`가 의미가 없으니까. 즉 **재사용성을 일부 희생하는 대신, view 코드의 반복과 실수를 크게 줄인 트레이드오프**다. 이게 퍼사드의 본질이다.

---

## `_get_queryset()` — 퍼사드 내부의 덕 타이핑

곁가지지만 짚어둘 만하다. `get_object_or_404()`는 모델 클래스만 받는 게 아니라 Manager, QuerySet도 받는다. 그 유연함을 내부 헬퍼가 처리한다.

```python
# django/shortcuts.py
def _get_queryset(klass):
    """
    Duck typing in action: any class with a `get()` method ... might do the job.
    """
    if hasattr(klass, "_default_manager"):
        return klass._default_manager.all()
    return klass
```

밑줄로 시작하는 비공개 함수라는 점이 의미심장하다. 퍼사드는 **공개 인터페이스(`get_object_or_404`)는 단순하게 유지하고, 지저분한 분기 처리는 비공개 헬퍼로 숨긴다.** "단순한 외관, 복잡한 내부"라는 퍼사드의 구조가 파일 안에서도 그대로 반복된다.

---

## 한 발 더: Requests의 `api.py`

같은 패턴을 다른 각도에서 보고 싶다면 `requests`의 top-level API가 좋은 예다.

소스: [requests/api.py](https://github.com/psf/requests/blob/main/src/requests/api.py)

```python
# requests/api.py (개념적으로 발췌)
def get(url, params=None, **kwargs):
    return request("get", url, params=params, **kwargs)

def request(method, url, **kwargs):
    with sessions.Session() as session:
        return session.request(method=method, url=url, **kwargs)
```

우리가 매일 쓰는 `requests.get(url)`은 사실 퍼사드다. 내부적으로는 `Session` 객체를 만들고, connection pooling을 설정하고, request를 prepare하고, 어댑터를 통해 전송하는 복잡한 과정이 있다. 사용자는 그 전부에 결합되지 않고 **top-level 함수 하나에만 결합된다.**

다만 Django와 달리 `requests`는 "controlled coupling"을 코드 주석으로 직접 선언하지는 않는다. 결합도라는 주제를 *말로 설명하기*에는 Django `shortcuts.py`가 더 선명한 이유다.

---

## 교과서 Facade와 `shortcuts.py`의 차이

패턴 포스트에서 본 퍼사드는 보통 **클래스** 형태였다 (`HomeTheaterFacade`, `ComputerFacade`). 서브시스템 객체들을 멤버로 들고 메서드에서 조율하는 구조 말이다. `shortcuts.py`는 다르다.

|  | 교과서 Facade | Django shortcuts.py |
|---|---|---|
| 형태 | 서브시스템을 멤버로 든 **클래스** | 모듈 레벨 **함수들의 집합** |
| 상태 | 인스턴스가 서브시스템 참조를 보관 | 무상태(stateless), 호출 시 import한 모듈 사용 |
| 진입점 | `facade.operation()` | `render()`, `redirect()`, `get_object_or_404()` |
| 결합 표현 | 암묵적 | docstring에 `controlled coupling` 명시 |

핵심 아이디어는 같다. "복잡한 여러 서브시스템을, 호출자가 한 곳만 알면 되도록 단순한 창구로 감싼다." Python에서는 굳이 클래스를 만들 필요 없이 **모듈 자체가 퍼사드 역할**을 할 수 있다는 점이 다를 뿐이다.

---

## 한 줄 정리

> `django/shortcuts.py`는 퍼사드가 "결합을 없애는 패턴"이 아니라 **"결합이 생길 수밖에 없는 지점을 의식적으로 한 곳에 모으는 패턴"** 임을 코드 주석으로까지 선언한다. `render()`, `redirect()`, `get_object_or_404()`는 view가 지킬 수 없는 계층 분리를 대신 떠안아, view 코드를 단순하게 유지한다.
