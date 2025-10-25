---
title: "Clerk 로그인 화면을 나의 앱에 도입하기"
date: 2025-10-25T16:45:00+09:00
draft: false
categories: ["API Manuals"]
tags: ["Authentification"]
---

# Session token 추가하기

Clerk Dashboard에 단 하나의 JSON 스니펫을 추가하면 사용자 메타데이터가 JWT 세션 토큰에 직접 포함되고, Vue Router의 네비게이션 가드를 사용해서 해당 토큰을 읽고 라우팅을 제어할 수 있다.

Clerk Console의 [Sessions 메뉴](http://dashboard.clerk.com/apps/app_34Mrxw8lQUzyaKDJvgZJ6JUDKGn/instances/ins_34Mrxs1f4zHBE4EUiNQW9nzVL3g/sessions) 중 `Customize session token`을 다음과 같이 수정하자.
```json
{
	"metadata": "{{user.public_metadata}}"
}
```
그 다음, 내 프로젝트의 `src/types/globals.d.ts`에 다음의 스크립트를 작성하여 애플리케이션에서 메타데이터 접근이 가능하게 한다.
```typescript
export {}

declare global {
  interface CustomJwtSessionClaims {
    metadata: {
      onboardingComplete?: boolean
      applicationName?: string
      applicationType?: string
    }
    firstName?: string
  }
}
```

이제 Clerk Dashboard에 session token에 custom 데이터를 추가했고, 이러한 claims를 앱에서 접근할 수 있게 만들었다.  

# 미들웨어 구성 (Vue Router Navigation Guards)
Vue.js에서는 Next.js 미들웨어 대신 Vue Router의 Navigation Guards를 사용하여 라우트 접근을 제어한다.  
**src/router/index.ts** 파일을 다음과 같이 구성:
```typescript
import { createRouter, createWebHistory } from 'vue-router'
import { useAuth } from '@clerk/vue'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/',
      name: 'Home',
      component: () => import('@/views/Home.vue'),
      meta: { isPublic: true }
    },
    {
      path: '/onboarding',
      name: 'Onboarding',
      component: () => import('@/views/Onboarding.vue'),
      meta: { isPublic: true }
    },
    {
      path: '/dashboard',
      name: 'Dashboard',
      component: () => import('@/views/Dashboard.vue'),
      meta: { requiresAuth: true }
    }
  ]
})

// Global Navigation Guard
router.beforeEach(async (to, from, next) => {
  const { userId, sessionClaims, isLoaded } = useAuth()

  // Clerk가 로드될 때까지 대기
  if (!isLoaded.value) {
    await new Promise(resolve => {
      const unwatch = watch(isLoaded, (loaded) => {
        if (loaded) {
          unwatch()
          resolve(true)
        }
      })
    })
  }

  const isPublicRoute = to.meta.isPublic
  const requiresAuth = to.meta.requiresAuth

  // 사용자가 로그인하지 않았고 라우트가 private인 경우
  if (!userId.value && requiresAuth) {
    // Clerk의 sign-in 페이지로 리다이렉트
    window.location.href = `/sign-in?redirect_url=${encodeURIComponent(to.fullPath)}`
    return
  }

  // 온보딩이 완료되지 않은 사용자를 /onboarding으로 리다이렉트
  if (
    userId.value &&
    !sessionClaims.value?.metadata?.onboardingComplete &&
    to.path !== '/onboarding'
  ) {
    next('/onboarding')
    return
  }

  // 온보딩을 완료한 사용자가 /onboarding에 접근하려는 경우
  if (
    userId.value &&
    sessionClaims.value?.metadata?.onboardingComplete &&
    to.path === '/onboarding'
  ) {
    next('/dashboard')
    return
  }

  // 그 외의 경우 정상 진행
  next()
})

export default router
```

# 백엔드 API 엔드포인트 추가 (FastAPI)
먼저 필요한 패키지를 설치:
**requirements.txt**
```txt
fastapi==0.109.0
uvicorn[standard]==0.27.0
clerk-backend-api==1.0.0
python-dotenv==1.0.0
pydantic==2.5.0
pydantic-settings==2.1.0
```

```bash
uv pip install -r requirements.txt
```

**.env**
```bash
CLERK_SECRET_KEY=your_clerk_secret_key
CLERK_PUBLISHABLE_KEY=your_clerk_publishable_key
```
(잊지 말자 `.gitignore`)  

## FastAPI 온보딩 엔드포인트 구현
**backend/app/routers/onboarding.py**
```python
from fastapi import APIRouter, HTTPException, Depends, Header
from pydantic import BaseModel, Field
from typing import Optional
from clerk_backend_api import Clerk
import os

router = APIRouter(prefix="/api", tags=["onboarding"])

# Clerk 클라이언트 초기화
clerk_client = Clerk(bearer_auth=os.getenv("CLERK_SECRET_KEY"))


class OnboardingRequest(BaseModel):
    applicationName: str = Field(..., min_length=1, max_length=100)
    applicationType: str = Field(..., min_length=1, max_length=50)


class OnboardingResponse(BaseModel):
    message: str
    success: bool


async def verify_clerk_session(authorization: str = Header(...)) -> str:
    """
    Clerk 세션 토큰을 검증하고 userId를 반환합니다.
    """
    try:
        # Bearer 토큰에서 실제 토큰 추출
        if not authorization.startswith("Bearer "):
            raise HTTPException(
                status_code=401, 
                detail="Invalid authorization header format"
            )
        
        token = authorization.replace("Bearer ", "")
        
        # Clerk 세션 검증
        session = clerk_client.sessions.verify_session(
            session_id=token,
        )
        
        if not session or not session.user_id:
            raise HTTPException(status_code=401, detail="Invalid session")
        
        return session.user_id
        
    except Exception as e:
        print(f"Session verification error: {e}")
        raise HTTPException(status_code=401, detail="Unauthorized")


@router.post("/complete-onboarding", response_model=OnboardingResponse)
async def complete_onboarding(
    request: OnboardingRequest,
    user_id: str = Depends(verify_clerk_session)
):
    """
    사용자의 온보딩을 완료하고 publicMetadata를 업데이트합니다.
    """
    try:
        # Clerk 사용자 메타데이터 업데이트
        clerk_client.users.update(
            user_id=user_id,
            public_metadata={
                "onboardingComplete": True,
                "applicationName": request.applicationName,
                "applicationType": request.applicationType,
            }
        )
        
        return OnboardingResponse(
            message="User metadata updated successfully",
            success=True
        )
        
    except Exception as e:
        print(f"Error updating user metadata: {e}")
        raise HTTPException(
            status_code=500,
            detail="Error updating user metadata"
        )


@router.get("/onboarding-status")
async def get_onboarding_status(
    user_id: str = Depends(verify_clerk_session)
):
    """
    사용자의 온보딩 상태를 확인합니다.
    """
    try:
        user = clerk_client.users.get(user_id=user_id)
        
        public_metadata = user.public_metadata or {}
        onboarding_complete = public_metadata.get("onboardingComplete", False)
        
        return {
            "onboardingComplete": onboarding_complete,
            "applicationName": public_metadata.get("applicationName"),
            "applicationType": public_metadata.get("applicationType")
        }
        
    except Exception as e:
        print(f"Error fetching user data: {e}")
        raise HTTPException(
            status_code=500,
            detail="Error fetching user data"
        )
```

## GCP Cloud Run 배포설정

**Dockerfile**
```dockerfile
FROM python:3.11-slim

WORKDIR /app

# 의존성 설치
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 애플리케이션 코드 복사
COPY ./app /app/app

# 포트 노출
EXPOSE 8080

# Uvicorn 서버 실행
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
```

**cloudbuild.yaml**
```yaml
steps:
  # Docker 이미지 빌드
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'build'
      - '-t'
      - 'gcr.io/$PROJECT_ID/onboarding-api:$SHORT_SHA'
      - '-t'
      - 'gcr.io/$PROJECT_ID/onboarding-api:latest'
      - '.'

  # Container Registry에 푸시
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'push'
      - 'gcr.io/$PROJECT_ID/onboarding-api:$SHORT_SHA'

  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'push'
      - 'gcr.io/$PROJECT_ID/onboarding-api:latest'

  # Cloud Run에 배포
  - name: 'gcr.io/cloud-builders/gcloud'
    args:
      - 'run'
      - 'deploy'
      - 'onboarding-api'
      - '--image'
      - 'gcr.io/$PROJECT_ID/onboarding-api:$SHORT_SHA'
      - '--region'
      - 'asia-northeast3'
      - '--platform'
      - 'managed'
      - '--allow-unauthenticated'
      - '--set-env-vars'
      - 'CLERK_SECRET_KEY=${_CLERK_SECRET_KEY},FRONTEND_URL=${_FRONTEND_URL}'

images:
  - 'gcr.io/$PROJECT_ID/onboarding-api:$SHORT_SHA'
  - 'gcr.io/$PROJECT_ID/onboarding-api:latest'
```

# 프론트엔드 Onboarding 컴포넌트

**src/views/Onboarding.vue**
```vue
<template>
  <div class="px-8 py-12 sm:py-16 md:px-20">
    <div class="mx-auto max-w-sm overflow-hidden rounded-lg bg-white shadow-lg">
      <div class="p-8">
        <h3 class="text-xl font-semibold text-gray-900">환영합니다!</h3>
      </div>
      
      <form @submit.prevent="handleSubmit">
        <div class="space-y-4 px-8 pb-8">
          <div>
            <label class="block text-sm font-semibold text-gray-700">
              Application Name
            </label>
            <p class="text-xs text-gray-500">애플리케이션의 이름을 입력하세요.</p>
            <input
              v-model="formData.applicationName"
              type="text"
              name="applicationName"
              class="mt-1 w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              required
            />
          </div>

          <div>
            <label class="block text-sm font-semibold text-gray-700">
              Application Type
            </label>
            <p class="text-xs text-gray-500">애플리케이션의 타입을 설명하세요.</p>
            <input
              v-model="formData.applicationType"
              type="text"
              name="applicationType"
              class="mt-1 w-full rounded-md border border-gray-300 px-3 py-2 shadow-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
              required
            />
          </div>
        </div>
        
        <div class="bg-gray-50 px-8 py-4">
          <button
            type="submit"
            :disabled="isSubmitting"
            class="w-full rounded bg-blue-500 px-4 py-2 text-white hover:bg-blue-600 disabled:bg-gray-400"
          >
            {{ isSubmitting ? '처리 중...' : '제출' }}
          </button>
        </div>
      </form>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth, useUser } from '@clerk/vue'

const router = useRouter()
const { getToken } = useAuth()
const { user } = useUser()

const isSubmitting = ref(false)
const formData = reactive({
  applicationName: '',
  applicationType: ''
})

const handleSubmit = async () => {
  isSubmitting.value = true

  try {
    // Clerk session 토큰 가져오기
    const token = await getToken()

    // 백엔드 API 호출
    const response = await fetch('/api/complete-onboarding', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify({
        applicationName: formData.applicationName,
        applicationType: formData.applicationType
      })
    })

    if (!response.ok) {
      throw new Error('Failed to update user metadata')
    }

    // 사용자 정보 새로고침
    await user.value?.reload()

    // 대시보드로 리다이렉트
    router.push('/dashboard')
  } catch (error) {
    console.error('Error completing onboarding:', error)
    alert('온보딩 완료 중 오류가 발생했습니다. 다시 시도해주세요.')
  } finally {
    isSubmitting.value = false
  }
}
</script>
```