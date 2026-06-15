---
title: "Iterator는 실전에서 이렇게 쓰인다 — boto3 ResourceCollection"
date: 2026-06-15T16:10:00+09:00
draft: false
categories: ["Code Reading"]
tags: ["boto3", "AWS", "Iterator", "반복자", "디자인패턴"]
---

> 이전 글 [Vibe Coding을 위한 디자인 패턴 - 반복자(Iterator)](/posts/design-pattern/designpattern-iterator/)를 읽었다는 가정 하에 쓴다.

## AWS 서비스 이름부터 — S3, EC2, SQS

boto3 코드를 읽으려면 글에 나오는 AWS 서비스 이름이 뭘 하는지부터 알아야 한다. 아래 세 가지만 잡고 가면 된다.

| 서비스 | 한 줄 설명 | 비유 |
|---|---|---|
| **S3** (Simple Storage Service) | 파일·이미지·백업 같은 **객체(파일) 저장소** | Google Drive / Dropbox 같은 클라우드 디스크 |
| **EC2** (Elastic Compute Cloud) | **가상 서버(컴퓨터)** 를 빌려 쓰는 서비스 | AWS 데이터센터 안의 원격 PC 한 대 |
| **SQS** (Simple Queue Service) | 서버끼리 **메시지를 줄 세워 전달**하는 큐 | 카카오톡 알림 대신, 백엔드 작업을 "잠깐 보관했다가 처리" |

S3는 **버킷(bucket)** 안에 **객체(object)** 를 넣는 구조다. EC2는 **인스턴스(instance)** 단위로 서버를 띄우고, SQS는 **큐(queue)** 에 메시지를 넣었다 꺼낸다. boto3에서는 이걸 각각 Python 객체처럼 다룬다.

---

## boto3가 뭔지 3줄

boto3는 Python에서 AWS를 다루는 공식 SDK다.  
위 서비스들의 버킷·인스턴스·큐를 `s3.Bucket(...)`, `ec2.Instance(...)` 같은 **Python 객체**로 조작하게 해준다.  
오늘 볼 코드는 그중에서도 S3 — "버킷 안의 객체 수십만 개를 어떻게 `for` 한 줄로 순회하게 만들었는가"이다.

---

## 문제: 100만 개짜리 컬렉션을 어떻게 순회할까

S3 버킷 하나에 객체가 100만 개 들어 있다고 하자. 우리가 쓰고 싶은 코드는 이렇다.

```python
bucket = s3.Bucket('boto3')
for obj in bucket.objects.all():
    print(obj.key)
```

리스트라면 간단하다. 하지만 여기엔 두 가지 현실의 벽이 있다.

- AWS API는 한 번에 최대 1000개씩만 돌려준다 (**페이지네이션**).
- 100만 개를 한꺼번에 메모리에 올릴 수 없다 (**지연 평가**).

반복자 패턴 글에서 본 "**컬렉션의 내부 표현을 숨기고 순차 접근만 노출**"이 정확히 필요한 상황이다. 클라이언트는 "다음 객체 줘"만 알면 되고, **페이지를 넘기는 일·HTTP 요청을 보내는 일은 반복자가 숨겨야 한다.**

---

## 해법: `__iter__`가 곧 반복자

핵심은 `ResourceCollection.__iter__`다.

```python
def __iter__(self):
    limit = self._params.get('limit', None)

    count = 0
    for page in self.pages():       # 페이지 단위로 받아온 뒤
        for item in page:           # 그 안의 항목을 하나씩
            yield item              # yield로 흘려보낸다

            count += 1
            if limit is not None and count >= limit:
                return
```

반복자 패턴 글에서 본 파이썬 내장 프로토콜 그대로다. `__iter__`가 제너레이터(`yield`)라서, `for obj in bucket.objects.all()`이 동작할 때 **항목을 미리 다 만들어두지 않는다.** 필요한 순간에 하나씩 꺼내온다.

패턴 글의 피보나치 예시와 본질이 같다.

```python
# designPattern-iterator.md 의 제너레이터 예시
def fibonacci(limit):
    a, b = 0, 1
    for _ in range(limit):
        yield a              # yield가 자동으로 순회 상태를 보관
        a, b = b, a + b
```

`yield`가 "다음 요소가 있나? 있으면 하나 줘"의 종료/진행 상태를 알아서 관리해주므로, `has_next()`/`next()`를 직접 구현할 필요가 없다.

---

## 순회 책임의 분리 — 2단계 제너레이터

boto3가 영리한 점은 순회를 **2층**으로 나눈 것이다.

```
__iter__()   →  "항목 하나씩"   (사용자가 보는 층)
   └─ pages()  →  "페이지 하나씩" (HTTP/페이지네이션을 처리하는 층)
```

`pages()`가 실제로 AWS를 호출하는 부분이다.

```python
def pages(self):
    client = self._parent.meta.client
    ...
    if client.can_paginate(self._py_operation_name):
        paginator = client.get_paginator(self._py_operation_name)
        pages = paginator.paginate(
            PaginationConfig={'MaxItems': limit, 'PageSize': page_size},
            **params,
        )
    else:
        pages = [getattr(client, self._py_operation_name)(**params)]

    count = 0
    for page in pages:
        page_items = []
        for item in self._handler(self._parent, params, page):
            page_items.append(item)
            count += 1
            if limit is not None and count >= limit:
                break
        yield page_items        # 페이지 단위로 흘려보냄
        if limit is not None and count >= limit:
            break
```

반복자 패턴 글의 핵심이 "**순회 로직을 컬렉션 자체에서 분리**"였다. boto3는 거기서 한 걸음 더 나아가, 순회 자체를 **"항목 순회"와 "페이지 순회"** 두 책임으로 또 나눴다.

- `pages()`: AWS API 호출, 페이지네이션, 응답을 자원 객체로 변환(`_handler`)
- `__iter__()`: 페이지를 펼쳐서 항목을 평탄하게(flatten) 흘려보냄

덕분에 사용자는 `pages()`(페이지 덩어리)와 `__iter__()`(개별 항목) 중 원하는 입도(granularity)를 골라 쓸 수 있다.

```python
# 항목 단위
for obj in bucket.objects.all(): ...

# 페이지 단위 (1000개씩 배치 처리하고 싶을 때)
for page in bucket.objects.pages():
    for obj in page: ...
```

이것이 패턴 글에서 말한 "**하나의 컬렉션에 여러 순회 방식을 제공**"의 실제 사례다.

---

## 내부 표현의 은닉 — paginate 여부조차 숨긴다

`pages()`를 보면 `can_paginate()`로 분기한다. 어떤 AWS 오퍼레이션은 페이지네이션을 지원하고 어떤 건 안 한다. 하지만 **사용자 코드는 그걸 알 필요가 없다.**

```python
if client.can_paginate(self._py_operation_name):
    pages = paginator.paginate(...)     # 페이지네이션 O
else:
    pages = [getattr(client, ...)(**params)]   # 페이지네이션 X → 단일 페이지 리스트로 위장
```

페이지네이션을 지원하지 않는 경우에도 결과를 `[단일_페이지]` 리스트로 감싸서, 위층의 `for page in pages`가 **똑같은 코드로 동작**하게 만든다.

반복자 패턴 글의 표현을 빌리면, 리스트든 트리든 같은 인터페이스로 순회하게 했던 것처럼 — 여기선 **"페이지네이션되는 API"든 "안 되는 API"든** 같은 순회 인터페이스 뒤로 숨겼다.

---

## Aggregate / Iterator 역할 매핑

패턴 글의 용어로 boto3 코드를 정리하면 이렇다.

| 패턴 용어 | boto3 구현 |
|---|---|
| Aggregate (집합 객체) | `CollectionManager` — `all()`, `filter()` 등으로 반복자 생성 |
| ConcreteAggregate | `s3.Bucket.objects` 같은 실제 매니저 |
| Iterator (반복자) | `ResourceCollection` — `__iter__`를 가진 객체 |
| 순회 상태(커서) | `pages()`/`__iter__`의 `count`, paginator 내부 토큰 |

`CollectionManager`는 **반복자가 아니다.** 문서에도 못 박혀 있다.

> A collection manager is **not iterable**. You must call one of the methods that return a `ResourceCollection` before trying to iterate.

이건 패턴 글에서 본 **Aggregate와 Iterator의 분리**를 그대로 지킨 것이다. `manager.all()`을 호출해야 비로소 순회 가능한 `ResourceCollection`이 나온다.

```python
sqs.queues          # CollectionManager — 순회 불가
sqs.queues.all()    # ResourceCollection — 순회 가능
```

---

## 보너스: 독립적인 순회 + 체이닝

패턴 글에서 강조한 "**같은 컬렉션을 여러 반복자가 독립적으로 순회**"도 보장된다. `filter()`/`limit()` 등이 매번 `_clone()`으로 **새 컬렉션을 복제**하기 때문이다.

```python
def _clone(self, **kwargs):
    params = copy.deepcopy(self._params)     # 파라미터를 깊은 복사
    merge_dicts(params, kwargs, append_lists=True)
    return self.__class__(self._model, self._parent, self._handler, **params)
```

원본을 건드리지 않고 복제본을 돌려주므로, 체이닝이 안전하다.

```python
base = collection.filter(Param1=1)
query1 = base.filter(Param2=2)   # {'Param1': 1, 'Param2': 2}
query2 = base.filter(Param3=3)   # {'Param1': 1, 'Param3': 3}
# base는 여전히 {'Param1': 1} — 서로 영향 없음
```

순회 상태(커서)를 반복자 객체로 옮긴 덕분에 가능한, 패턴 글의 "잘된 예"와 정확히 같은 구조다.

---

## 패턴 vs 실전 — 무엇이 달랐나

| | 패턴 글의 교과서 예시 | boto3 ResourceCollection |
|---|---|---|
| 인터페이스 | `has_next()` / `next()` | 파이썬 내장 `__iter__` + `yield` |
| 데이터 출처 | 메모리 안의 리스트/트리 | 원격 AWS API (HTTP) |
| 핵심 추가 과제 | — | 페이지네이션, 지연 평가 |
| 순회 입도 | 항목 단위 | 항목(`__iter__`) / 페이지(`pages`) 선택 |
| 반복자 생성 | `create_iterator()` | `all()` / `filter()` / `_clone()` |

교과서의 `has_next()`/`next()`는 파이썬에선 `yield` 하나로 대체된다. boto3는 거기에 **"순회 = 원격 자원을 페이지 단위로 lazy하게 당겨오는 일"** 이라는 현실의 무게를 얹었을 뿐, 패턴의 뼈대는 그대로다.

---

## 한 줄 정리

> boto3 `ResourceCollection`은 **"100만 개짜리 원격 컬렉션의 페이지네이션과 지연 평가"라는 복잡함을 `yield` 뒤에 통째로 숨겨**, 사용자에게는 `for obj in bucket.objects.all()` 한 줄만 남기는 Iterator 패턴의 정석 사례다.

원본 코드: [boto3/resources/collection.py](https://github.com/boto/boto3/blob/develop/boto3/resources/collection.py)
