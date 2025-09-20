#!/bin/bash

# Hugo 사이트 빌드 및 GitHub main 브랜치 배포
echo "Hugo 사이트를 빌드하고 main 브랜치에 푸시합니다..."

# Hugo 빌드
hugo

# Git에 모든 변경사항 추가
git add .

# 커밋 (타임스탬프 포함)
git commit -m "Deploy update $(date '+%Y-%m-%d %H:%M:%S')"

# main 브랜치에 푸시 (GitHub Actions이 자동으로 배포)
git push origin main

echo "배포가 완료되었습니다! GitHub Actions가 자동으로 사이트를 빌드하고 배포합니다."
echo "몇 분 후 https://deliciouscat.github.io/ 에서 확인할 수 있습니다."