#!/usr/bin/python3
# -*- coding: utf-8 -*-

import logging

import base64

FORMAT = '[%(levelname)s-%(asctime)-15s]-%(message)s'
logging.basicConfig(format=FORMAT, level=logging.DEBUG)


def encode_base64(data):
    return (base64.b64encode(data.encode())).decode()


def decode_base64(data):
    return (base64.b64decode(data.encode())).decode()
