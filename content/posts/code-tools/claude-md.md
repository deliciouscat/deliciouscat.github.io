---
title: "Cursor 제대로 사용하기 - CLAUDE.md"
date: 2099-10-14T12:55:00+09:00
draft: false
categories: ["Productivity"]
tags: ["Cursor", "Claude", "Vibe Coding"]
---

# 용도
`CLAUDE.md`는 본래 Claude Code를 사용할 때 지침을 커스텀하기 위한 제어영역이다. Claude 모델이 알지 못하는 프로젝트 고유의 지침, 가령:
- 원하는 코드 수정의 범위
- 사용되는 기술 스택
- 프로젝트 구조
- 외부 도구의 bash 명령어
- 커밋 명령어 규칙 등의 저장소 에티켓
- MSA 구조 상에서 상호작용하는 컴포넌트의 인터페이스
- **DO NOT TOUCH** 목록(작동하는 레거시 코드 등)  
등을 포함할 수 있다.  

# 세팅
IDE인 Cursor 환경에서도 Claude Code의 기능을 사용할 수 있다. 먼저 Claude CLI 환경의 설치부터. (Node.js의 설치가 선행되어있어야 함)
```
npm install -g @anthropic-ai/claude-code
```
설치가 완료되면, Cursor의 `편집기 오른쪽으로 분할` 버튼 옆에 주황색 Claude Code 아이콘이 나오는 것을 확인할 수 있을 것이다.(Cursor는 VScode 기반이기 때문) 또는, 하단 터미널에서 `claude` 명령어로 CLI 환경에서 제어할 수 있다. 안내에 따라 Claude CLI에 로그인을 하면 된다.  
현재 프로젝트 루트에서, 우측 콘솔이든 `claude` 명령으로 접근한 CLI 환경이든 `/init` 명령어를 실행하면, 현재 프로젝트를 Claude Code가 분석하여 구조화된 `CLAUDE.md`를 작성해준다.(상당히 괜찮은 완성도로!)

# 배치 및 적용
- 홈 디렉토리 (`~/.claude/CLAUDE.md`): 어떤 프로젝트에서 Claude를 사용하던 전역적으로 적용됨.
- 프로젝트 루트 (`your-repo/CLAUDE.md`): 특정 프로젝트에 공통으로 적용됨. 가장 일반적으로 사용하는 위치.
- 하위 디렉토리 (`your-repo/feature/CLAUDE.md`): 프로젝트의 특정 부분에서 사용할 수 있음.
- 로컬 오버라이드 (`CLAUDE.local.md`): 저장소에 커밋하지 않고 개인적인 지침도 가능하다. `CLAUDE.local.md` 파일을 생성하고 `.gitignore`에 추가.

만약에 위 예시의 모든 위치에 `CLAUDE.md`가 존재한다면,

# 효과적인 `CLAUDE.md` 작성
`CLAUDE.md`를 통한 instruction도 제한된 입력 토큰의 일부를 사용해야 하고, 지나치게 장황하고 구체적인 작성은 오히려 모델의 기본 성능을 발휘하는 것을 방해할 가능성이 있다.  
[제안되는](https://clzd.me/posts/whats-a-claude-md-file-and-why-it-matters-in-claude-code-projects/) 작성 양식을 소개하자면,  
1. 짧고 명확한 bullet point 노테이션
2. 중복적 구문 제거
3. 장황하게 설명하지 x (주니어 개발자를 온보딩하듯이 작성하면 안됨)
4. Claude가 '이 프로젝트에 국한해서' 알아야 할 요소를 작성

### 잘못된 예
```
## Comment Component Specification

This component is designed to display user comments with expandable functionality.

### Required Imports
`Markdown` is a lightweight markup language that values readability, allowing you to format and convert text into HTML, etc.
- We need to import the color template CSS file for styling
- We need to import a markdown library that is appropriate for our framework
- We need to import a katex library for mathematical expressions

### Props Definition
The component accepts the following props:
- nametag: This is a string that represents the user's name
- content: This is a string containing the comment text
- commentId: This is a unique string identifier for the comment
- isExpanded: This is a boolean that tracks expansion state
- onExpand: This is a callback function that takes an id parameter
```
-> 지나치게 지루하고 현학적이다. JSON으로 입력해도 알아듣는 LLM에게 이렇게 사람에게 설명하듯이 지시할 필요가 없다. 모델이 이미 알고 있는 Markdown의 개념을 구태여 다시 설명할 필요도 없다.  

### 잘된 예
```
## Comment Component

**Imports**
- `color_template.css`
- Markdown + KaTeX libs (framework-specific)

**Props**
- `nametag: string` - user display name
- `content: string` - comment body (markdown + math)
- `commentId: string` - unique ID
- `isExpanded: boolean` - expansion state
- `onExpand: (id) => void` - expand handler

**Layout**: Vertical stack
- Nametag
- 8px gap
- Content (rendered if expanded, raw otherwise)

**Styling**
- Border: 1px grey-lv2
- Height: 96px collapsed, auto expanded
- Background: white (expanded) / grey-lv1 (hover) / white (default)
- Bottom fade gradient when collapsed

**Behavior**
- Click expands → calls `onExpand(commentId)`
- Stop event propagation
```
-> "This is", "We need to" 같은 어구를 반복할 필요도 없으며, `commentId`같은 자명한 property를 구구절절 설명할 필요가 없다.


