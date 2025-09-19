#!/bin/sh

# Hugo 사이트 빌드
echo "Building the website..."
hugo -D

# public 디렉토리로 이동
cd public

# 변경사항 추가
git add .

# 커밋 메시지 설정
msg="rebuilding site `date`"
if [ $# -eq 1 ]
  then msg="$1"
fi

# 커밋 및 푸시 (gh-pages 브랜치)
git commit -m "$msg"
git push origin gh-pages

# 프로젝트 루트로 돌아가기
cd ..

# main 브랜치에도 변경사항 커밋 및 푸시
git add .

msg="rebuilding site `date`"
if [ $# -eq 1 ]
  then msg="$1"
fi

git commit -m "$msg"
git push origin main

echo "배포가 완료되었습니다!"