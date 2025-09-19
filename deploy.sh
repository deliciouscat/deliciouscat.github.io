#!/bin/sh

# Hugo 사이트 빌드 (public 폴더로 출력)
echo "Building the website..."
hugo

# public 폴더의 내용을 root로 복사 (User Pages는 root에서 배포)
echo "Copying public contents to root..."
cp -r public/* .

# 변경사항 추가
git add .

# 커밋 메시지 설정
msg="rebuilding site `date`"
if [ $# -eq 1 ]
  then msg="$1"
fi

# main 브랜치에 커밋 및 푸시 (User Pages는 root에서 자동 배포)
git commit -m "$msg"
git push origin main

echo "배포가 완료되었습니다! User Pages가 root 디렉토리에서 자동으로 사이트를 배포합니다."