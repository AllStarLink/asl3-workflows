#!/bin/bash

set -e
set -x

while [[ $# -gt 0 ]]; do
  case $1 in
    -c|--check-changelog)
      CHECK_CHANGELOG=YES
      shift
      ;;
    -a|--architecture)
      ARCH_ASK="$2"
      shift
      shift
      ;;
    -t|--targets)
      TARGETS="$2"
      shift
      shift
      ;;
    -r|--commit-versioning)
      COMMIT_VERSIONING=YES
      shift
      ;;
    -o|--operating-systems)
      OPERATING_SYSTEMS="$2"
      shift
      shift
      ;;
	--ast-ver)
      AST_VER="$2"
      shift
	  shift
      ;;
	--rpt-ver)
      RPT_VER="$2"
      shift
      shift
      ;;
	--asl3-ver)
      ASL3_VER="$2"
      shift
      shift
	  ;;
	--gh-rel)
	  GH_REL="$2"
	  shift
	  shift
	  ;;
    -*|--*|*)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done

if [ -z "$ARCH_ASK" ]
then
  ARCH="all"
fi

case $ARCH_ASK in
	arm64)
		ARCH=arm64v8
		;;
	armhf)
		ARCH=arm32v7
		;;
	*)
		ARCH=$ARCH_ASK
		;;
esac

if [ -z "$TARGETS" ]
then
  TARGETS="asl3-asterisk"
fi

if [ -z "$OPERATING_SYSTEMS" ]
then
  OPERATING_SYSTEMS="bookworm"
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD)

if [ $BRANCH == "develop" ]; then
  REPO_ENV="-devel"
elif [ $BRANCH = "testing"]; then
  REPO_ENV="-testing"
else
  REPO_ENV=""
fi

## Need to clean this up to be more elegant
echo "Architectures: $ARCH"
echo "Targets: $TARGETS"
echo "Operating Systems: $OPERATING_SYSTEMS"
echo "PWD: $(pwd)"
echo "BS: ${BASH_SOURCE[0]}"
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
echo "DIR: ${DIR}"
PDIR=$(dirname $DIR)
echo "PDIR: ${PDIR}"
ALL_PKG_ROOT=$(dirname ${PDIR})
echo "ALL_PKG_ROOT: ${ALL_PKG_ROOT}"

DPKG_BUILDOPTS="-b -uc -us"

git config --system url.https://$GITHUB_TOKEN@github.com/.insteadOf https://github.com
git config --system user.email "builder@allstarlink.org"
cd $ALL_PKG_ROOT
git clone https://github.com/AllStarLink/app_rpt
git clone https://github.com/AllStarLink/ASL3 

D_TAG="asl3-asterisk_builder.${OPERATING_SYSTEMS}.${ARCH}${REPO_ENV}"

docker build -f $DIR/Dockerfile -t $D_TAG \
	--build-arg ARCH="$ARCH" \
	--build-arg OS="$OPERATING_SYSTEMS" \
	--build-arg ASL_REPO="asl_builds${REPO_ENV}" \
	--build-arg USER_ID=$(id -u) \
	--build-arg GROUP_ID=$(id -g) \
	$DIR
 
docker run -v $ALL_PKG_ROOT:/build \
	-e DPKG_BUILDOPTS="$DPKG_BUILDOPTS" \
	-e BUILD_TARGETS="$TARGETS" \
   	-e AST_VER="$AST_VER" \
	-e RPT_VER="$RPT_VER" \
	-e ASL3_VER="$ASL3_VER" \
 	-e GH_TOKEN="$GH_TOKEN" \
  	-e GITHUB_TOKEN="$GITHUB_TOKEN" \
	$D_TAG

DEBIAN_FRONTEND=noninteractive apt-get -y install gh
gh release upload -R AllStarLink/asl3-asterisk $GH_REL $ALL_PKG_ROOT/_debs/*.deb

docker image rm --force $D_TAG
