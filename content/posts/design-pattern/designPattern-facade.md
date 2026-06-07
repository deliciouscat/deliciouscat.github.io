---
title: "Vibe Coding을 위한 디자인 패턴 - 퍼사드(Facade)"
date: 2026-06-07T16:52:00+09:00
draft: false
categories: ["Computer Science"]
tags: ["디자인패턴", "Vibe Coding", "퍼사드", "Facade"]
---

# Facade Pattern (퍼사드 패턴)

Facade Pattern(퍼사드 패턴)은 복잡한 서브시스템(여러 클래스, 라이브러리, 프레임워크의 집합)에 대한 **단순화된 통합 인터페이스를 제공**하는 구조 디자인 패턴이다.
'Facade(파사드)'는 건물의 정면을 뜻하는 단어로, 내부의 복잡한 구조를 가린 채 깔끔한 외관만을 보여준다는 의미를 담고 있다.

예를 들어:
```python
# 복잡한 서브시스템
class CPU:
    def freeze(self): return "CPU 정지"
    def jump(self, position): return f"{position} 위치로 점프"
    def execute(self): return "명령 실행"

class Memory:
    def load(self, position, data): return f"{position}에 {data} 로드"

class HardDrive:
    def read(self, lba, size): return f"섹터 {lba}에서 {size}만큼 읽기"

# 퍼사드: 복잡한 부팅 과정을 하나의 메서드로 단순화
class ComputerFacade:
    def __init__(self):
        self.cpu = CPU()
        self.memory = Memory()
        self.hard_drive = HardDrive()

    def start(self):
        self.cpu.freeze()
        boot_data = self.hard_drive.read(0, 1024)
        self.memory.load(0, boot_data)
        self.cpu.jump(0)
        self.cpu.execute()
        return "컴퓨터 부팅 완료"

# 클라이언트는 복잡한 내부 과정을 몰라도 됨
computer = ComputerFacade()
print(computer.start())  # 컴퓨터 부팅 완료
```
→ 클라이언트는 `CPU`, `Memory`, `HardDrive`의 복잡한 상호작용을 알 필요 없이 `start()` 메서드 하나만 호출하면 된다. **퍼사드가 서브시스템의 복잡성을 캡슐화**한다.

## 최소 지식 원칙 (디미터의 법칙)

Facade Pattern은 최소 지식 원칙(Least Knowledge Principle), 즉 **디미터의 법칙(Law of Demeter)**과 깊은 관련이 있다. 이 원칙은 '객체는 자신과 밀접한 관계에 있는 객체하고만 대화해야 한다'는 것을 의미한다. 객체 간의 결합도가 높으면 한 부분의 변경이 시스템 전체로 퍼지기 때문이다.

먼저 이 원칙이 지켜지지 않은 예시를 보자.

**잘못된 예:**
```python
class HomeTheaterClient:
    def watch_movie(self, movie):
        # 클라이언트가 모든 서브시스템의 세부 사항을 직접 알아야 함
        amp = Amplifier()
        tuner = Tuner()
        dvd = DvdPlayer()
        projector = Projector()
        screen = Screen()
        lights = TheaterLights()

        lights.dim(10)
        screen.down()
        projector.on()
        projector.set_input(dvd)
        projector.wide_screen_mode()
        amp.on()
        amp.set_dvd(dvd)
        amp.set_surround_sound()
        amp.set_volume(5)
        dvd.on()
        dvd.play(movie)
```
위의 코드를 보면 클라이언트가 6개의 서브시스템 객체와 직접 소통하면서 영화 재생 절차의 모든 순서를 직접 알고 있어야 한다. 서브시스템의 사용법이 바뀌면 클라이언트 코드도 모두 수정해야 하며, 다른 곳에서 영화를 재생하려면 이 복잡한 코드를 또 작성해야 한다. (클라이언트와 서브시스템 간의 결합도가 너무 높음!)

**잘된 예:**
```python
class HomeTheaterFacade:
    def __init__(self, amp, tuner, dvd, projector, screen, lights):
        self.amp = amp
        self.tuner = tuner
        self.dvd = dvd
        self.projector = projector
        self.screen = screen
        self.lights = lights

    def watch_movie(self, movie):
        self.lights.dim(10)
        self.screen.down()
        self.projector.on()
        self.projector.set_input(self.dvd)
        self.projector.wide_screen_mode()
        self.amp.on()
        self.amp.set_dvd(self.dvd)
        self.amp.set_surround_sound()
        self.amp.set_volume(5)
        self.dvd.on()
        self.dvd.play(movie)
        return f"영화 '{movie}' 재생 시작"

    def end_movie(self):
        self.lights.on()
        self.screen.up()
        self.projector.off()
        self.amp.off()
        self.dvd.stop()
        self.dvd.off()
        return "영화 종료"

# 클라이언트는 퍼사드하고만 대화
home_theater = HomeTheaterFacade(amp, tuner, dvd, projector, screen, lights)
home_theater.watch_movie("인터스텔라")
home_theater.end_movie()
```
이렇게 하면 클라이언트는 `HomeTheaterFacade`라는 하나의 객체하고만 대화하면 된다. 복잡한 재생/종료 절차는 퍼사드가 캡슐화하므로, 서브시스템이 바뀌어도 클라이언트 코드는 영향을 받지 않는다. **클라이언트와 서브시스템 간의 결합도가 크게 낮아진다.**

**클라이언트는 단순한 인터페이스(퍼사드)하고만 상호작용하고, 복잡성은 퍼사드 뒤에 숨긴다!**

Facade Pattern의 핵심은 **결합도 분리(Decoupling)**이다.
- 클라이언트와 서브시스템 사이의 의존성을 줄인다
- 서브시스템의 변경이 클라이언트로 전파되는 것을 막는다
- 단, 퍼사드는 서브시스템에 대한 접근을 막지는 않는다 (필요하면 클라이언트가 직접 서브시스템에 접근 가능)

## 실제 사용 예시: 주문 처리 시스템
```python
# 서브시스템들
class Inventory:
    def check(self, item):
        return f"{item} 재고 확인 (충분함)"

class Payment:
    def process(self, amount):
        return f"{amount}원 결제 완료"

class Shipping:
    def arrange(self, item):
        return f"{item} 배송 준비"

class Notification:
    def send(self, message):
        return f"알림 발송: {message}"

# 퍼사드
class OrderFacade:
    def __init__(self):
        self.inventory = Inventory()
        self.payment = Payment()
        self.shipping = Shipping()
        self.notification = Notification()

    def place_order(self, item, amount):
        results = []
        results.append(self.inventory.check(item))
        results.append(self.payment.process(amount))
        results.append(self.shipping.arrange(item))
        results.append(self.notification.send(f"{item} 주문이 완료되었습니다"))
        return results

# 클라이언트는 주문 절차의 복잡함을 몰라도 됨
order = OrderFacade()
for step in order.place_order("노트북", 1500000):
    print(step)
# 노트북 재고 확인 (충분함)
# 1500000원 결제 완료
# 노트북 배송 준비
# 알림 발송: 노트북 주문이 완료되었습니다
```

## 언제 Facade Pattern을 사용해야 하는가?

Facade Pattern은 다음과 같은 상황에서 유용하다:

### 1. 복잡한 서브시스템에 대한 단순한 인터페이스가 필요할 때

시스템이 복잡해지면서 점점 더 많은 클래스들이 생기고, 의미 있는 작업 하나를 수행하기 위해 여러 객체를 특정 순서로 초기화하고 호출해야 하는 경우가 생긴다. 그 결과 서브시스템 클래스들의 비즈니스 로직이 클라이언트 코드와 강하게 결합되어 코드를 이해하고 유지보수하기 어려워진다.

퍼사드는 가장 자주 사용되는 기능들만 포함하는 편리한 단축 인터페이스를 제공하여 이러한 복잡성을 숨긴다.

예시:
- 복잡한 라이브러리/프레임워크의 사용을 단순화
- 컴퓨터 부팅 과정 (CPU, 메모리, 디스크 등의 조율)
- 홈시어터 시스템 (여러 기기의 조율)

### 2. 서브시스템을 계층(layer)으로 구조화하고 싶을 때

각 서브시스템 수준의 진입점으로 퍼사드를 만들어 사용한다. 여러 서브시스템들이 서로 통신해야 할 때 퍼사드들을 통해서만 통신하도록 하면, 서브시스템 간의 결합도를 낮출 수 있다.

예시:
- 마이크로서비스 간 통신 게이트웨이(API Gateway)
- 다계층 아키텍처에서 각 계층의 진입점

## 구현 방법

1. 기존 서브시스템이 제공하는 기능보다 더 단순한 인터페이스를 제공할 수 있는지 확인. 이 인터페이스가 클라이언트 코드를 여러 서브시스템 클래스들로부터 독립적으로 만들어야 한다.

2. 새 퍼사드 클래스에 이 인터페이스를 선언하고 구현. 퍼사드는 클라이언트의 호출을 서브시스템의 적절한 객체들로 리다이렉트(전달)해야 한다. 또한 퍼사드는 서브시스템을 올바르게 초기화하고 그 수명 주기를 관리할 책임을 져야 한다 (클라이언트가 이를 이미 하고 있지 않다면).

3. 모든 클라이언트 코드가 오직 퍼사드를 통해서만 서브시스템과 소통하도록 한다. 이제 서브시스템 코드의 변경으로부터 클라이언트 코드가 보호된다. 예를 들어 서브시스템이 새 버전으로 업그레이드되어도, 퍼사드 안의 코드만 수정하면 된다.

4. 퍼사드가 너무 커지면, 그 행동의 일부를 새롭고 더 정교한 퍼사드 클래스로 추출하는 것을 고려한다.

## 장단점

### 장점

✅ **서브시스템의 복잡성으로부터 코드를 격리할 수 있음**
- 클라이언트는 복잡한 내부 구조를 몰라도 단순한 인터페이스만으로 작업할 수 있다.

✅ **클라이언트와 서브시스템 간의 결합도를 낮춤**
- 디미터의 법칙을 준수하여, 서브시스템 변경이 클라이언트로 전파되는 것을 막는다.

✅ **코드의 가독성과 유지보수성이 향상됨**
- 자주 쓰이는 기능을 하나의 진입점으로 모아 코드를 이해하기 쉬워진다.

### 단점

❌ **퍼사드가 앱의 모든 클래스에 결합된 '신 객체(God Object)'가 될 수 있음**
- 너무 많은 책임이 퍼사드에 집중되면 거대하고 복잡한 클래스가 되어버린다.

❌ **유연성이 제한될 수 있음**
- 단순화된 인터페이스만 제공하므로, 서브시스템의 모든 세부 기능을 활용하기 어려울 수 있다. (단, 퍼사드가 서브시스템에 대한 직접 접근을 막지는 않는다.)

## 퍼사드 vs 다른 패턴

**퍼사드 vs 어댑터(Adapter)**: 어댑터는 기존 인터페이스를 클라이언트가 기대하는 다른 인터페이스로 *변환*하는 데 초점을 둔다. 반면 퍼사드는 복잡한 서브시스템에 대한 *새롭고 단순한* 인터페이스를 정의한다.

**퍼사드 vs 데코레이터(Decorator)**: 데코레이터는 객체의 인터페이스를 바꾸지 않고 기능을 추가하지만, 퍼사드는 여러 객체를 감싸 완전히 새로운 단순한 인터페이스를 제공한다.

**퍼사드 vs 중재자(Mediator)**: 둘 다 결합도를 줄이지만, 중재자는 컴포넌트들이 서로 직접 통신하는 대신 중재자를 거치도록 *강제*한다. 반면 퍼사드는 서브시스템에 대한 단순한 인터페이스를 제공할 뿐, 서브시스템 객체들은 여전히 퍼사드를 인식하지 못하며 직접 접근도 가능하다.

## 용어 정리

**Facade (퍼사드)**: 서브시스템의 특정 기능들에 대한 편리한 접근을 제공하는 클래스. 클라이언트의 요청을 어디로 보낼지, 어떻게 조작할지 알고 있다.  
**Subsystem (서브시스템)**: 수십 개의 다양한 객체들로 구성된 복잡한 시스템. 퍼사드의 존재를 알지 못하며, 시스템 내부에서 서로 직접 작동한다.  
**Client (클라이언트)**: 서브시스템 객체들을 직접 호출하는 대신 퍼사드를 사용하는 코드.

1. 컴퓨터 부팅 예시:
- Facade (퍼사드) → ComputerFacade
- Subsystem (서브시스템) → CPU, Memory, HardDrive

2. 홈시어터 예시:
- Facade (퍼사드) → HomeTheaterFacade
- Subsystem (서브시스템) → Amplifier, Tuner, DvdPlayer, Projector, Screen, TheaterLights

3. 주문 처리 예시:
- Facade (퍼사드) → OrderFacade
- Subsystem (서브시스템) → Inventory, Payment, Shipping, Notification

## 한 줄 요약

Facade Pattern은 **복잡한 서브시스템을 단순한 하나의 창구로 감싸는** 패턴이다.

즉:

> "이 복잡한 것들을 일일이 어떻게 다루지?"가 아니라, "창구에 말하면 알아서 처리해주겠지"로 만든다.
