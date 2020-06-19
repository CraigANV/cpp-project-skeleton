#!/usr/bin/env bash

set -eux

exec > >(tee "build.log") 2>&1
date

function mkcd()
{
  rm -rf "$1" && mkdir "$1" && pushd "$1"
}

function revert_conan_uninstall()
{
  # revert simulated uninstall (if present)
  if [[ -d ~/.conan/data.bk ]]; then
    mv ~/.conan/data.bk ~/.conan/data
  fi
}

function conan_uninstall()
{
  mv ~/.conan/data ~/.conan/data.bk # simulate uninstall to save time
}

# Make the script agnostic to where its called from
pushd "$(dirname "$(readlink -f "$0")")" > /dev/null

readonly APT_PACKAGES="libboost-all-dev libgtest-dev libbz2-dev"

# TODO: Remove any apt install packages that may confuse things
#sudo apt remove -y $APT_PACKAGES
#sudo apt autoremove -y

# Remove old install
sudo rm -rf /usr/local/include/skeleton/ /usr/local/lib/libskeleton* /usr/local/lib/cmake/Skeleton/

revert_conan_uninstall

# Build libskeleton release and debug against Conan packages and install to /usr/local/
pushd libskeleton
mkcd build

conan install .. --build=missing -r=artifactory # conan remote list

cmake .. -DUSE_CONAN_PACKAGE=True -DCMAKE_BUILD_TYPE=Debug
cmake --build . --parallel 2
ctest
cpack
sudo cmake --install .

if grep -ir conan /usr/local/lib/cmake/Skeleton/; then
  printf "INFO: Targets coupled to Conan\n"
fi

cmake .. -DUSE_CONAN_PACKAGE=True -DCMAKE_BUILD_TYPE=Release
cmake --build . --parallel 2
ctest
cpack
sudo cmake --install .

popd

# Build without Conan packages (just to prove it works, doesn't install)
sudo apt install -y $APT_PACKAGES
mkcd build2

cmake ..
cmake --build . --parallel 2
ctest

if grep -ir conan SkeletonTargets.cmake; then
  printf "ERROR: Targets coupled to Conan\n"
  exit 1
fi

revert_conan_uninstall

popd
popd

# Build consumer against Conan linked libskeleton and Conan installed dependencies
pushd consumer
mkcd build
cmake .. -DCMAKE_BUILD_TYPE=Debug
cmake --build .
./skeletonconsumer

popd

# TODO: Build consumer against Conan linked libskeleton and apt installed dependencies (not working yet)
#sudo apt install -y $APT_PACKAGES
#conan_uninstall
#conan search
#mkcd build2
#cmake .. -DCMAKE_BUILD_TYPE=Debug
#cmake --build .
#./skeletonconsumer

revert_conan_uninstall
