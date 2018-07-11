#!/bin/sh

docker build -t vmctf-ldap ldap/ && \
  docker build -t vmctf .
