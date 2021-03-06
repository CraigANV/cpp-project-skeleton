#!/usr/bin/env bash

set -ex

exec > >(tee "build.log") 2>&1
date

function mkcd()
{
  rm -rf "$1" && mkdir "$1" && pushd "$1"
}

function revert_conan_uninstall()
{
  # revert simulated uninstall
  if [[ -d ~/.conan/data.bk ]]; then
    mv ~/.conan/data.bk ~/.conan/data
  fi
}

function conan_uninstall()
{
  # simulate uninstall to save time
  if [[ -d ~/.conan/data ]]; then
    mv ~/.conan/data ~/.conan/data.bk
  fi
}

# Make the script agnostic to where its called from
pushd "$(dirname "$(readlink -f "$0")")" > /dev/null

cmake --version
gcc --version
make --version

# Different profiles can be selected from ../conan/profiles
# The default profile used is ~/.conan/profiles/default
readonly CONAN_DIR="../conan/"
conan_profile="${HOME}/.conan/profiles/default"
if [[ $1 == "clang" || $CC == "*clang" || $CXX == "*clang++" ]]; then
  export CC=${CC:-clang}
  export CXX=${CXX:-clang++}
  conan_profile="${CONAN_DIR}/profiles/clang"
elif [[ ! -z $1 ]]; then
  conan_profile="${CONAN_DIR}/profiles/$1"
fi

set -u

readonly APT_PACKAGES="libboost-all-dev libgtest-dev libbz2-dev libpoco-dev libopencv-dev"

# Remove old install
sudo rm -rf /usr/local/include/skeleton/ /usr/local/lib/libskeleton* /usr/local/lib/cmake/Skeleton/
#sudo apt -y purge $APT_PACKAGES
#sudo apt -y autoremove

revert_conan_uninstall

# Build libskeleton release and debug against Conan packages and install to /usr/local/
pushd libskeleton
mkcd build

conan install "${CONAN_DIR}" --build=missing -pr="$conan_profile"

cmake .. -DUSE_CONAN_PACKAGE=True -DCMAKE_BUILD_TYPE=Debug
cmake --build . --parallel 2
ctest
cpack
sudo cmake --install .
make clean

grep -ir INTERFACE_INCLUDE_DIRECTORIES /usr/local/lib/cmake/Skeleton/
grep -ir INTERFACE_LINK_LIBRARIES /usr/local/lib/cmake/Skeleton/

cmake .. -DUSE_CONAN_PACKAGE=True -DCMAKE_BUILD_TYPE=Release
cmake --build . --parallel 2
ctest
cpack
sudo cmake --install .
make clean

popd

# Build without Conan packages (just to prove it works, doesn't install)
sudo apt install -y $APT_PACKAGES
#../scripts/install_opencv.sh

readonly OS_VERSION=$(lsb_release -rs)
if [[ $OS_VERSION == "18.04" ]]; then
  pushd /usr/src/gtest;
  sudo cmake -DCMAKE_BUILD_TYPE=RELEASE .;
  sudo make -j $(nproc); \
  sudo cp libg* /usr/lib/;
  popd
fi

conan_uninstall
mkcd build2

cmake ..
cmake --build . --parallel 2
ctest
make clean
popd

if grep -ir conan SkeletonTargets.cmake; then
  printf "ERROR: Targets coupled to Conan\n"
  exit 1
fi

revert_conan_uninstall

popd

# Build consumer against Conan linked libskeleton and apt installed dependencies
sudo apt install -y $APT_PACKAGES
#./scripts/install_opencv.sh
conan_uninstall
conan search

pushd consumer
mkcd build
cmake .. -DCMAKE_BUILD_TYPE=Debug
cmake --build .
./skeletonconsumer

revert_conan_uninstall

printf "\n\n Building with and without Conan packages successfully\n"