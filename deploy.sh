#!/bin/sh

# Hugo 사이트 빌드 (docs 폴더로 출력)
echo "Building the website..."
hugo

# 변경사항 추가 (docs 폴더와 소스 파일들 모두)
git add .

# 커밋 메시지 설정
msg="rebuilding site `date`"
if [ $# -eq 1 ]
  then msg="$1"
fi

# main 브랜치에 커밋 및 푸시 (GitHub Pages는 docs 폴더에서 자동 배포)
git commit -m "$msg"
git push origin main

echo "배포가 완료되었습니다! GitHub Pages가 docs 폴더에서 자동으로 사이트를 배포합니다."