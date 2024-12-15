set(micro_ros_base_path "/opt/microros")
#set(micro_ros_base_path "/home/kaylor/work/stm32/libmicroros-stm32f407-dev/files/opt/microros")
set(MICRO_ROS_INCLUDE_DIRS ${micro_ros_base_path}/microros_static_library/libmicroros/microros_include)
include_directories(${MICRO_ROS_INCLUDE_DIRS})
set(MICRO_ROS_LIB ${micro_ros_base_path}/microros_static_library/libmicroros/libmicroros.a)
if(NOT MICRO_ROS_TRANSPORT)
  set(MICRO_ROS_TRANSPORT dma)  
endif()
set(MICRO_ROS_SRC
        ${micro_ros_base_path}/extra_sources/custom_memory_manager.c
        ${micro_ros_base_path}/extra_sources/microros_allocators.c
        ${micro_ros_base_path}/extra_sources/microros_time.c
        ${micro_ros_base_path}/extra_sources/microros_transports/${MICRO_ROS_TRANSPORT}_transport.c
)
