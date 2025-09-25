---
title: "Vibe Coding을 위한 디자인 패턴 - 관찰자(Observer)"
date: 2025-09-25T17:00:00+09:00
draft: false
categories: ["Computer Science"]
tags: ["디자인패턴", "관찰자", "Observer"]
---

# Observer Pattern (관찰자 패턴)

Observer Pattern(관찰자 패턴)은 객체 간의 **일대다(one-to-many) 의존 관계**를 정의하여, 한 객체의 상태가 변경되면 그에 의존하는 모든 객체들에게 **자동으로 알림을 전달**하고 업데이트하는 행동 디자인 패턴이다.

클라이언트가 **Subject**(관찰 대상)과 **Observer**(관찰자)를 느슨하게 결합된 방식으로 상호작용할 수 있게 한다.

예를 들어:
```python
class Subject:
    def __init__(self):
        self.observers = []
    def attach(self, observer): self.observers.append(observer)
    def notify(self): 
        for observer in self.observers:
            observer.update(self)

class Observer:
    def update(self, subject): pass

class ConcreteSubject(Subject):
    def __init__(self): 
        super().__init__()
        self.state = 0
    def set_state(self, state): 
        self.state = state
        self.notify()  # 상태 변경 시 자동 알림

class ConcreteObserver(Observer):
    def __init__(self, name): self.name = name
    def update(self, subject): 
        print(f"{self.name}: 상태가 {subject.state}로 변경됨")

# 클라이언트는 Subject와 Observer를 구분하지 않음
stock = ConcreteSubject()
investor1 = ConcreteObserver("투자자A")
investor2 = ConcreteObserver("투자자B")

stock.attach(investor1)  # 관찰자 등록(투자자A가 주식을 관찰)
stock.attach(investor2)  # 관찰자 등록
stock.set_state(100)     # 투자자A: 상태가 100으로 변경됨
                         # 투자자B: 상태가 100으로 변경됨
```
→ `ConcreteSubject`와 `ConcreteObserver`는 모두 각각 `Subject`, `Observer` 인터페이스를 구현해서 **발행-구독 메커니즘**을 통해 느슨하게 결합된다.

## 단일 책임 원칙 / 개방-폐쇄 원칙

Composite Pattern과 마찬가지로 Observer Pattern을 사용할 땐 이 원칙들을 준수해야 하는데, 먼저 단일 책임 원칙(Single Responsibility Principle; SRP)이 지켜지지 않은 예시를 보자.

**잘못된 예:**
```python
class NewsSystem:
    def __init__(self):
        self.subscribers = []
        self.news = ""
        
    def add_subscriber(self, subscriber):
        self.subscribers.append(subscriber)
        
    def set_news(self, news):
        self.news = news
        # 뉴스 업데이트와 동시에 여러 책임을 담당
        for sub in self.subscribers:
            if sub.type == "email":
                self.send_email(sub, news)  # 이메일 전송 책임
            elif sub.type == "sms":
                self.send_sms(sub, news)    # SMS 전송 책임
            elif sub.type == "push":
                self.send_push(sub, news)   # 푸시 알림 책임
                
    def send_email(self, sub, news): pass  # 이메일 전송 로직
    def send_sms(self, sub, news): pass    # SMS 전송 로직
    def send_push(self, sub, news): pass   # 푸시 알림 로직


print("=== 잘못된 예 (SRP 위반) 시연 ===")
bad_news = NewsSystem()
subscriber1 = Subscriber("김개발", "email")
subscriber2 = Subscriber("박디자인", "sms")
subscriber3 = Subscriber("이기획", "push")

bad_news.add_subscriber(subscriber1)
bad_news.add_subscriber(subscriber2)
bad_news.add_subscriber(subscriber3)
bad_news.set_news("첫 번째 뉴스")
# 뉴스 발행: 첫 번째 뉴스
# 이메일 전송: 김개발에게 첫 번째 뉴스
# SMS 전송: 박디자인에게 첫 번째 뉴스
# 푸시 알림: 이기획에게 첫 번째 뉴스
```
위의 코드를 보면 `NewsSystem`이 뉴스 관리뿐만 아니라 다양한 알림 방식의 구체적인 전송 로직까지 담당하고 있다. 게다가 새로운 알림 방식이 추가될 때마다 `NewsSystem`을 수정해야 한다. 이 코드를 SRP를 준수하도록 수정하자.

**잘된 예:**
```python
class Subject:
    def __init__(self):
        self.observers = []
    def attach(self, observer): self.observers.append(observer)
    def detach(self, observer): self.observers.remove(observer)
    def notify(self): 
        for observer in self.observers:
            observer.update(self)

class NewsAgency(Subject):  # 뉴스 관리에만 집중
    def __init__(self):
        super().__init__()
        self.news = ""
    def set_news(self, news):
        self.news = news
        self.notify()

class Observer:
    def update(self, subject): pass

class EmailNotifier(Observer):  # 이메일 알림에만 집중
    def update(self, subject):
        print(f"이메일 전송: {subject.news}")

class SMSNotifier(Observer):    # SMS 알림에만 집중
    def update(self, subject):
        print(f"SMS 전송: {subject.news}")

print("=== Observer Pattern 시연 ===")

# 클라이언트는 NewsAgency와 각 Notifier를 구분하지 않음
good_news = NewsAgency()
kim_dev = EmailNotifier("김개발")
park_designer = SMSNotifier("박디자인")
lee_planner = PushNotifier("이기획")

good_news.attach(kim_dev)       # 관찰자 등록
good_news.attach(park_designer) # 관찰자 등록
good_news.attach(lee_planner)   # 관찰자 등록
good_news.set_news("첫 번째 뉴스")
# 뉴스 발행: 첫 번째 뉴스
# 이메일 전송: 김개발에게 첫 번째 뉴스
# SMS 전송: 박디자인에게 첫 번째 뉴스
# 푸시 알림: 이기획에게 첫 번째 뉴스
```
이렇게 하면 뉴스 관리는 `NewsAgency`가, 각각의 알림 방식은 해당 `Observer`가 담당하게 된다.

Observer Pattern에서도 개방-폐쇄 원칙(Open-Closed Principle; OCP)은 중요하다. ('Entity는 확장에는 열려있고, 수정에는 닫혀있어야 한다')

**잘못된 예:**
```python
class StockMonitor:
    def __init__(self):
        self.watchers = []
        
    def price_changed(self, stock_price):
        for watcher in self.watchers:
            if watcher.type == "investor":
                watcher.notify_price_change(stock_price)
            elif watcher.type == "news":
                watcher.publish_news(stock_price)
            elif watcher.type == "alert":
                watcher.send_alert(stock_price)
```
→ 이렇게 하면 새로운 종류의 관찰자(예: 분석 시스템)를 추가할 때마다 `StockMonitor`를 수정해야 하는 구조이다. (확장에 대해 개방성이 없다)

**잘된 예:**
```python
class Observer:
    def update(self, subject): pass

class StockPrice(Subject):
    def __init__(self, symbol):
        super().__init__()
        self.symbol = symbol
        self.price = 0
    def set_price(self, price):
        self.price = price
        self.notify()  # 새로운 Observer 추가해도 기존 코드 수정 불필요

class InvestorObserver(Observer):
    def update(self, subject):
        print(f"투자 전략 업데이트: {subject.symbol} = ${subject.price}")

class NewsObserver(Observer):
    def update(self, subject):
        print(f"뉴스 발행: {subject.symbol} 가격 변동")

class AnalysisObserver(Observer):  # 새로운 Observer도 쉽게 추가
    def update(self, subject):
        print(f"분석 시작: {subject.symbol} 데이터 분석")
```
이제, 새로운 관찰자를 추가하고자 할 때엔 `Observer` 클래스를 상속하여 쉽게 기능을 확장할 수 있으며(확장에는 개방), `StockPrice` 클래스에 별도의 코드를 추가할 필요가 없다. (수정에는 닫혀있다.)

**각 클래스가 명확한 단일 책임, 각 컴포넌트들이 인터페이스(`Subject`, `Observer` 등)를 통해서만 상호작용!**

Observer Pattern의 가장 큰 특징은 **발행-구독(Pub-Sub) 메커니즘**이다. Subject는 상태 변화를 발행(publish)하고, Observer들은 해당 변화를 구독(subscribe)한다.
- 런타임에 동적으로 관찰자 등록/해제 가능
- 브로드캐스트 통신으로 일대다 알림
- Subject와 Observer 간의 느슨한 결합

## Observer Pattern은 다음과 같은 상황에서 유용하다:

1. **상태 변화 알림이 필요할 때**
ex.)
- 주식 가격 모니터링 시스템 (가격 변동 → 투자자들에게 알림)
- GUI 이벤트 처리 (버튼 클릭 → 여러 컴포넌트 반응)
- 데이터 바인딩 (모델 변경 → 뷰 업데이트)

2. **일대다 의존 관계를 구현해야 할 때 (발행-구독 특성!)**
ex.)
- 뉴스 구독 시스템 (뉴스 발행 → 구독자들에게 전달)
- 이벤트 처리 시스템 (이벤트 발생 → 리스너들에게 통지)

## 용어 정리

**Subject (관찰 대상)**: Observer들을 관리하고 상태 변화 시 알림을 보내는 객체  
**Observer (관찰자)**: Subject의 상태 변화를 관찰하고 알림을 받아 반응하는 객체  
**ConcreteSubject (구체적 관찰 대상)**: 실제 상태를 가지고 변화를 감지하는 구체적인 Subject  
**ConcreteObserver (구체적 관찰자)**: 실제 알림에 대한 구체적인 반응을 구현하는 Observer

1. 주식 모니터링 시스템 예시:
- Subject (관찰 대상) → Subject
- Observer (관찰자) → Observer  
- ConcreteSubject (구체적 관찰 대상) → StockPrice
- ConcreteObserver (구체적 관찰자) → InvestorObserver, NewsObserver

2. GUI 이벤트 시스템 예시:
- Subject (관찰 대상) → EventSource
- Observer (관찰자) → EventListener
- ConcreteSubject (구체적 관찰 대상) → Button, TextField
- ConcreteObserver (구체적 관찰자) → ClickHandler, ChangeHandler