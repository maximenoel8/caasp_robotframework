#!/usr/bin/python3
# -*- coding: utf-8 -*-

import json
import logging
import re

regex = re.compile(r"\[.*(\"\n)")

FORMAT = '[%(levelname)s-%(asctime)-15s]-%(message)s'
logging.basicConfig(format=FORMAT, level=logging.DEBUG)


def convert_tvars_to_dico(terraform_file):
    logging.debug(terraform_file)
    with open(terraform_file, "rb") as terraform_file:
        file_data = terraform_file.readlines()
        logging.debug(file_data)
        new_file = "{\n"
        for line in file_data:
            # logging.debug(line)
            line = line.decode('utf8')
            logging.debug(line)
            if not line.startswith('#') and not len(line.strip()) == 0:
                new_file = new_file + line
    new_file = new_file.replace("[\n", "[")
    new_file = new_file.replace("=", ":")
    new_file = new_file.replace(",\n", ",")
    new_file = new_file.replace("[.*(\"\n)", "\"")
    new_file = re.sub(r"(\[.*\")\n", r"\1 ", new_file)
    new_file = re.sub(r"(\w+(-?|_?)\w+?) :", r'"\1" :', new_file)
    new_file = re.sub(r"(\n.* : *.*)", r'\1,', new_file)
    new_file = re.sub(r",$", r'', new_file)
    new_file = new_file + "}"
    logging.debug(new_file)
    distros_dict = json.loads(new_file)
    # logging.debug(distros_dict)
    return distros_dict


def convert_dictionary_to_json(dictionary):
    return json.dumps(dictionary)
