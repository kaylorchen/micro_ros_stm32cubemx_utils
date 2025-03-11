#!/bin/bash
apt-get update
apt-get install -y debhelper devscripts fakeroot curl wget gcc-arm-none-eabi binutils-arm-none-eabi libnewlib-arm-none-eabi libnewlib-dev libstdc++-arm-none-eabi-dev libstdc++-arm-none-eabi-newlib rsync sudo
set +e
SOURCE_ROOT=$(pwd)
BASE_PATH=${SOURCE_ROOT}/microros_static_library
echo "BASE_PATH = $BASE_PATH"
rm -rf ${SOURCE_ROOT}/artifacts
mkdir -pv ${SOURCE_ROOT}/artifacts
set -xe
mkdir -pv /uros_ws
cd /uros_ws
git clone https://github.com/micro-ROS/micro_ros_setup.git --depth 1 -b humble
rm install -rf
source /opt/ros/$ROS_DISTRO/setup.bash
rosdep update
colcon build
source install/setup.bash
ros2 run micro_ros_setup create_firmware_ws.sh generate_lib
pushd firmware/mcu_ws > /dev/null
  git clone -b humble --depth 1 https://github.com/ros2/geometry2.git 
  cp -R geometry2/tf2_msgs ros2/tf2_msgs
  rm -rf geometry2
  mkdir extra_packages
  pushd extra_packages > /dev/null
    USER_CUSTOM_PACKAGES_DIR=$BASE_PATH/../../microros_component/extra_packages 
    if [ -d "$USER_CUSTOM_PACKAGES_DIR" ]; then
        echo "USER_CUSTOM_PACKAGES_DIR exists"
        cp -R $USER_CUSTOM_PACKAGES_DIR/* .
    fi
    if [ -f $USER_CUSTOM_PACKAGES_DIR/extra_packages.repos ]; then
      vcs import --input $USER_CUSTOM_PACKAGES_DIR/extra_packages.repos
    fi
    cp -R $BASE_PATH/library_generation/extra_packages/* .
    cat extra_packages.repos
    vcs import --input extra_packages.repos
    if [ -z $UP_REPO ]; then
      echo "UP_REPO is empty"
      UP_REPO=master
    fi
    echo "upstream repository is $UP_REPO"
    echo $UP_REPO | tee ${SOURCE_ROOT}/artifacts/target_repo
    git clone https://github.com/kaylorchen/kaylordut_interfaces.git --depth 1000 -b ${UP_REPO}  ros2/kaylordut_interfaces
    cd ros2/kaylordut_interfaces
    VERSION=$(git describe --tags --long).${UP_REPO}.$(TZ="Asia/Shanghai" date +"%Y%m%d.%H%M%S").${DIST}
    VERSION=$(echo ${VERSION} | tr _ -)
  popd > /dev/null
popd > /dev/null
pushd ${SOURCE_ROOT} > /dev/null
cat f407.cflags
export RET_CFLAGS=$(cat f407.cflags)
RET_CODE=$?
if [ $RET_CODE = "0" ]; then
    echo "Found CFLAGS:"
    echo "-------------"
    echo $RET_CFLAGS
    echo "-------------"
else
    echo "Please read README.md to update your Makefile"
    exit 1;
fi
popd > /dev/null
export TOOLCHAIN_PREFIX=/usr/bin/arm-none-eabi-
ros2 run micro_ros_setup build_firmware.sh $BASE_PATH/library_generation/toolchain.cmake $BASE_PATH/library_generation/colcon.meta
find firmware/build/include/ -name "*.c"  -delete
rm -rf $BASE_PATH/libmicroros
mkdir -p $BASE_PATH/libmicroros/microros_include
cp -vR firmware/build/include/* $BASE_PATH/libmicroros/microros_include/
cp -vR firmware/build/libmicroros.a $BASE_PATH/libmicroros/libmicroros.a
pushd firmware/mcu_ws > /dev/null
    INCLUDE_ROS2_PACKAGES=$(colcon list | awk '{print $1}' | awk -v d=" " '{s=(NR==1?s:s d)$0}END{print s}')
popd > /dev/null

for var in ${INCLUDE_ROS2_PACKAGES}; do
    if [ -d "$BASE_PATH/libmicroros/microros_include/${var}/${var}" ]; then
        rsync -r $BASE_PATH/libmicroros/microros_include/${var}/${var}/* $BASE_PATH/libmicroros/microros_include/${var}
        rm -rf $BASE_PATH/libmicroros/microros_include/${var}/${var}
    fi
done
find firmware/mcu_ws/ros2 \( -name "*.srv" -o -name "*.msg" -o -name "*.action" \) | awk -F"/" '{print $(NF-2)"/"$NF}' > $BASE_PATH/libmicroros/available_ros2_types
find firmware/mcu_ws/extra_packages \( -name "*.srv" -o -name "*.msg" -o -name "*.action" \) | awk -F"/" '{print $(NF-2)"/"$NF}' >> $BASE_PATH/libmicroros/available_ros2_types
cd firmware
echo "" > $BASE_PATH/libmicroros/built_packages
for f in $(find $(pwd) -name .git -type d); do pushd $f > /dev/null; echo $(git config --get remote.origin.url) $(git rev-parse HEAD) >> $BASE_PATH/libmicroros/built_packages; popd > /dev/null; done;
sudo chmod -R 777 $BASE_PATH/libmicroros/
sudo chmod -R 777 $BASE_PATH/libmicroros/microros_include/
sudo chmod -R 777 $BASE_PATH/libmicroros/libmicroros.a
DEBIAN_DIR=${SOURCE_ROOT}/f407
cp -vR ${SOURCE_ROOT}/extra_sources ${DEBIAN_DIR}/files/opt/microros_f407/
cp -vR $BASE_PATH/libmicroros ${DEBIAN_DIR}/files/opt/microros_f407/microros_static_library/
tar -czvf microros.tar.gz ${DEBIAN_DIR}/files/opt/microros_f407/
cp -vR microros.tar.gz ${SOURCE_ROOT}/artifacts
export EMAIL=kaylor.chen@qq.com
git config --global --add safe.directory ${SOURCE_ROOT}
pushd ${DEBIAN_DIR}
  dch -b -v ${VERSION} $(git log -n 1 --pretty=format:"%s")
  DEB_BUILD_OPTIONS=parallel=15 fakeroot debian/rules binary
  mv -v ../*.deb ${SOURCE_ROOT}/artifacts
popd