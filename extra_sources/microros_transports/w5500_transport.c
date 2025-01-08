//
// Created by kaylor on 1/8/25.
//
#include <rmw_microxrcedds_c/config.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <uxr/client/transport.h>

#include "Ethernet/socket.h"
#include "Ethernet/wizchip_conf.h"
#include "cmsis_os.h"
#ifdef RMW_UXRCE_TRANSPORT_CUSTOM
// --- micro-ROS Transports ---
#define UDP_PORT 8888
#define SN 0
#ifndef DATA_BUF_SIZE
#define DATA_BUF_SIZE 2048
#endif
static int sock_fd = -1;

bool cubemx_transport_open(struct uxrCustomTransport *transport) {
  int ret = 0;
  while (1) {
    int sn_sr = getSn_SR(SN);
    printf("sn_sr=%d\n", sn_sr);
    switch (sn_sr) {
      case SOCK_CLOSED:
        if ((ret = socket(SN, Sn_MR_UDP, UDP_PORT, 0x00)) != SN)
          return false;
        break;
      case SOCK_UDP:
        sock_fd = 0;
		printf("micro ros create udp socket sucessfully\n");
        return true;
        break;
      default:
        break;
    }
  }
  return true;
}

bool cubemx_transport_close(struct uxrCustomTransport *transport) {
  if (sock_fd != -1) {
    close(SN);
    sock_fd = -1;
  }
  return true;
}
// 定义返回状态枚举
typedef enum {
  PARSE_OK,    // 解析成功
  PARSE_ERROR  // 解析出错
} ParseResult;

// 解析IP地址和端口的函数
ParseResult parse_ip_and_port(const char *str, uint8_t ip[4], uint16_t *port) {
  // 检查输入参数是否合法
  if (str == NULL || ip == NULL || port == NULL) {
    return PARSE_ERROR;
  }

  // 将str指向的字符串复制到本地缓冲区，以便使用strtok等函数
  char buffer[30] = {0};
  strncpy(buffer, str, sizeof(buffer));
  buffer[sizeof(buffer) - 1] = '\0';  // 确保字符串结束符

  // 使用strtok解析出IP地址
  char *token = strtok(buffer, ".");
  for (int i = 0; i < 4; i++) {
    if (token == NULL) {
      return PARSE_ERROR;
    }
    int byte = atoi(token);
    if (byte < 0 || byte > 255) {
      return PARSE_ERROR;  // IP地址不合法
    }
    ip[i] = (uint8_t)byte;
    token = strtok(NULL, i < 2 ? "." : ":");
  }

  // 解析端口号
  if (token == NULL) {
    return PARSE_ERROR;
  }
  *port = (uint16_t)atoi(token);

  return PARSE_OK;
}

size_t cubemx_transport_write(struct uxrCustomTransport *transport,
                              uint8_t *buf, size_t len, uint8_t *err) {
  if (sock_fd == -1) {
    return 0;
  }
  const char *input = (const char *)transport->args;
  uint16_t port;
  uint8_t ip[4];
  parse_ip_and_port(input, ip, &port);
  //printf("ip = %d.%d.%d.%d:%d\n", ip[0], ip[1],ip[2],ip[3], port);
  size_t sent_len = 0;
  while (sent_len != len) {
    int ret = sendto(SN, buf + sent_len, len - sent_len, ip, port);
    if (ret < 0) {
      return ret;
    }
    sent_len += ret;
  }
  return sent_len;
}

size_t cubemx_transport_read(struct uxrCustomTransport *transport, uint8_t *buf,
                             size_t len, int timeout, uint8_t *err) {
  int ret = 0;
  const char *input = (const char *)transport->args;
  uint16_t port;
  uint8_t ip[4];
  parse_ip_and_port(input, ip, &port);
  // set timeout
  struct timeval tv_out;
  tv_out.tv_sec = timeout / 1000;
  tv_out.tv_usec = (timeout % 1000) * 1000;
  size_t readed = 0;
  size_t size = 0;
  if (getSn_SR(SN) == SOCK_UDP) {
    if ((size = getSn_RX_RSR(SN)) > 0) {
      if (size > DATA_BUF_SIZE) size = DATA_BUF_SIZE;
      readed = recvfrom(SN, buf, len, ip, (uint16_t *)&port);
    }
  }
  return readed;
}

#endif
