#!/bin/sh

docker build -t vmctf-ldap openldap/ && \
  docker build -t vmctf .
